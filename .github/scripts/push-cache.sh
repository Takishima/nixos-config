#!/usr/bin/env bash
# Pushes the free parts of what this job built, as recorded by
# record-built.sh, to the public Cachix cache.
# Usage: push-cache.sh <cache> <system>; DRY_RUN=1 only lists.
#
# cachix pushes a path with its whole closure, so a path whose closure
# reaches an unfree package is left out.
set -euo pipefail

cache=$1
system=$2
here=$(dirname "$0")
built=${BUILT_PATHS:-/nix/var/nix/built-paths}

# Not worth pushing. The two checks are rebuilt on every commit.
skip='-(source|user-environment|treefmt-check|statix)$'

# Unfree packages a free one wraps, which unfree-paths.nix cannot see.
hidden='copilot-language-server-[0-9]'

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ -e "$built" ]; then
  sort -u "$built" | { grep -vE -- "$skip" || true; } | while read -r path; do
    if nix-store --check-validity "$path" 2>/dev/null; then echo "$path"; fi
  done
fi >"$work/candidates"

if [ ! -s "$work/candidates" ]; then
  echo "Nothing was built."
  exit 0
fi

nix eval --json .#nixosConfigurations --apply "
  hosts:
  let
    unfree = ($(cat "$here/unfree-paths.nix"));
    here = builtins.filter (host: host.config.nixpkgs.hostPlatform.system == \"$system\") (builtins.attrValues hosts);
  in
  builtins.concatMap (host: unfree host.config) here
" | jq -r '.[]' | sort -u >"$work/unfree"

: >"$work/roots"
while read -r root; do
  nix-store --query --requisites "$root" | sort -u >"$work/closure"
  if grep -qE "^/nix/store/[a-z0-9]{32}-$hidden" "$work/closure" ||
    [ -n "$(comm -12 "$work/closure" "$work/unfree")" ]; then
    echo "Not pushed, its closure holds an unfree package: $root"
  else
    echo "$root" >>"$work/roots"
  fi
done <"$work/candidates"

if [ ! -s "$work/roots" ]; then
  echo "Nothing to push."
  exit 0
fi

echo "Pushing the closures of:"
cat "$work/roots"
if [ -z "${DRY_RUN:-}" ]; then
  cachix push "$cache" <"$work/roots"
fi
