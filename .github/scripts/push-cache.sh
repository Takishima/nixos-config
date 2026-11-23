#!/usr/bin/env bash
# Pushes the expensive, free parts of what `nix flake check` built to the
# public Cachix cache. Usage: push-cache.sh <cache> <system>; DRY_RUN=1 only
# lists. The hosts are those of that system: its toplevel-<host> checks.
#
# cachix pushes a path together with its whole closure, so a filter that
# excludes unfree packages cannot work: the system closure brings them back.
# Instead only the paths named here are pushed, and one whose closure reaches
# an unfree package is left out.
set -euo pipefail

cache=$1
system=$2
here=$(dirname "$0")

# Packages in the hosts' closures that cache.nixos.org does not have and that
# take long to build. Matched against the store path's name. Add to it when
# CI starts compiling something else. Emacs's packages go one by one: Emacs
# with all of them holds the unfree Copilot server.
allow='(ncro|luciole|nh|gdk-pixbuf|librsvg|linux-rpi|emacs-[[:alnum:]+_.-]+)-[0-9]'

# Unfree packages a free one wraps, which unfree-paths.nix cannot see.
hidden='copilot-language-server-[0-9]'

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

nix eval --json ".#checks.$system" \
  --apply 'checks: builtins.mapAttrs (_: check: check.outPath) checks' >"$work/checks.json"

# `nix flake check` does not fetch a result a cache already has, so a path
# missing from the store here needs no push.
valid() {
  while read -r path; do
    if nix-store --check-validity "$path" 2>/dev/null; then echo "$path"; fi
  done
}

: >"$work/unfree"
{
  for host in $(jq -r 'keys[] | select(startswith("toplevel-")) | ltrimstr("toplevel-")' "$work/checks.json"); do
    toplevel=$(jq -r --arg check "toplevel-$host" '.[$check]' "$work/checks.json")
    if [ -n "$(echo "$toplevel" | valid)" ]; then
      nix-store --query --requisites "$toplevel" |
        grep -E "^/nix/store/[a-z0-9]{32}-$allow" || true
    fi
    nix eval --json ".#nixosConfigurations.$host.config" --apply "$(cat "$here/unfree-paths.nix")" |
      jq -r '.[]' >>"$work/unfree"
  done
  # The other checks' results, so an unchanged test is not run again.
  jq -r 'with_entries(select(.key | startswith("toplevel-") | not))[]' "$work/checks.json" | valid
} | sort -u >"$work/candidates"
sort -u -o "$work/unfree" "$work/unfree"

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
