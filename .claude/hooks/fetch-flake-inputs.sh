#!/usr/bin/env bash
# Puts the locked flake inputs in the Nix store over git, then tells Claude.
# A cloud session's proxy serves git fetches but refuses GitHub's tarballs.
set -euo pipefail

cd "$CLAUDE_PROJECT_DIR"

stateDir=$HOME/.cache/fetch-flake-inputs
fetchedLock=$stateDir/flake.lock.sha256
mkdir -p "$stateDir"
exec 2>>"$stateDir/log"
echo "$(date --iso-8601=seconds) start" >&2

workDir=$(mktemp -d)
trap 'rm -rf "$workDir"' EXIT
touch "$workDir/failed"
maxParallelFetches=8

logAs() {
  awk -v source="$1" '{ print source ": " $0 }' >&2
}

record() {
  local name=$1
  shift
  if "$@" 2> >(logAs "$name"); then
    echo "$name: in the store" >&2
  else
    echo "$name: failed" >&2
    echo "$name" >>"$workDir/failed"
  fi
}

# `git archive` gives the tree of GitHub's tarball, which the lock's hash is of.
addGitTree() {
  local repo=$1 name=$2 rev=$3 lockedHash=$4 addedHash
  local tree=$workDir/$name
  mkdir "$tree"
  git -C "$repo" archive "$rev" | tar -x -C "$tree"
  addedHash=$(nix hash path "$tree")
  if [ "$addedHash" != "$lockedHash" ]; then
    echo "flake.lock has $lockedHash, git gave $addedHash" >&2
    return 1
  fi
  nix store add --name source "$tree" >/dev/null
  rm -rf "$tree"
}

# One fetch for every locked revision: the proxy limits transfers per repository.
fetchGithubInputs() {
  local url=$1 inputs name rev lockedHash
  local repo
  repo=$(mktemp -d -p "$workDir")
  inputs=$(cat)
  git init --quiet --bare "$repo"
  if ! awk '{ print $2 }' <<<"$inputs" | sort -u |
    GIT_LFS_SKIP_SMUDGE=1 xargs git -C "$repo" fetch --quiet --depth 1 "$url" \
      2> >(logAs "$url"); then
    awk '{ print $1 }' <<<"$inputs" >>"$workDir/failed"
    echo "$url: failed" >&2
    return
  fi
  while read -r name rev lockedHash; do
    record "$name" addGitTree "$repo" "$name" "$rev" "$lockedHash" &
  done <<<"$inputs"
  wait
  rm -rf "$repo"
}

fetchInputsOfOneUrl() {
  local type=$1 url=$2 name lockedHash
  echo "$url: fetching" >&2
  case $type in
    github) fetchGithubInputs "$url" ;;
    tarball)
      while read -r name _ lockedHash; do
        record "$name" nix flake prefetch "$url?narHash=$lockedHash"
      done
      ;;
  esac
}

fetchInputs() {
  local inputs type url
  inputs=$(
    jq -r '
      .nodes | to_entries[] | .key as $name | .value.locked | select(.) |
      if .type == "github" then
        "\($name) github https://github.com/\(.owner)/\(.repo) \(.rev) \(.narHash)"
      elif .type == "tarball" then
        "\($name) tarball \(.url) - \(.narHash)"
      else
        error("\($name): no fetch rule for a \(.type) input")
      end
    ' flake.lock
  )
  echo "$(wc -l <<<"$inputs") inputs" >&2
  while read -r type url; do
    while [ "$(jobs -rp | wc -l)" -ge "$maxParallelFetches" ]; do
      wait -n
    done
    awk -v url="$url" '$3 == url { print $1, $4, $5 }' <<<"$inputs" |
      fetchInputsOfOneUrl "$type" "$url" &
  done < <(awk '{ print $2, $3 }' <<<"$inputs" | sort -u)
  wait
}

if sha256sum --check --status "$fetchedLock" 2>/dev/null; then
  echo "flake.lock has not changed since the last fetch" >&2
else
  fetchInputs
  if [ ! -s "$workDir/failed" ]; then
    sha256sum "$PWD/flake.lock" >"$fetchedLock"
  fi
fi

if [ -s "$workDir/failed" ]; then
  message="Fetching these flake inputs failed: $(paste -sd' ' "$workDir/failed"). The errors are in $stateDir/log."
else
  message="The flake inputs are in the Nix store: nix eval, nix build, nix fmt and nix flake check can run."
fi
echo "$message" >&2

jq -n --arg message "$message" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $message}}'
