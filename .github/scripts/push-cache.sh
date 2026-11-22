#!/usr/bin/env bash
# Pushes the expensive, free parts of what `nix flake check` built to the
# public Cachix cache. Usage: push-cache.sh <cache>; DRY_RUN=1 only lists.
#
# cachix pushes a path together with its whole closure, so a filter that
# excludes unfree packages cannot work: the system closure brings them back.
# Instead only the paths named here are pushed, and the push is refused if
# their closure reaches a package the configuration marks as unfree.
set -euo pipefail

cache=$1
system=x86_64-linux
host=homelinux
here=$(dirname "$0")

# Packages in the host's closure that cache.nixos.org does not have and that
# take long to build. Matched against the store path's name. Add to it when
# CI starts compiling something else; never add an unfree package.
allow='(ncro|luciole|nh|emacs-pgtk-with-packages|gdk-pixbuf|librsvg)-[0-9]'

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

nix eval --json ".#checks.$system" \
  --apply 'checks: builtins.mapAttrs (_: check: check.outPath) checks' >"$work/checks.json"
toplevel=$(jq -r .toplevel "$work/checks.json")

# `nix flake check` does not fetch a result a cache already has, so a path
# missing from the store here needs no push.
valid() {
  while read -r path; do
    if nix-store --check-validity "$path" 2>/dev/null; then echo "$path"; fi
  done
}

{
  if [ -n "$(echo "$toplevel" | valid)" ]; then
    nix-store --query --requisites "$toplevel" |
      grep -E "^/nix/store/[a-z0-9]{32}-$allow" || true
  fi
  # The other checks' results, so an unchanged test is not run again.
  jq -r 'del(.toplevel)[]' "$work/checks.json" | valid
} | sort -u >"$work/roots"

if [ ! -s "$work/roots" ]; then
  echo "Nothing to push: every result came from a cache."
  exit 0
fi

nix eval --json ".#nixosConfigurations.$host.config" --apply "$(cat "$here/unfree-paths.nix")" |
  jq -r '.[]' | sort -u >"$work/unfree"
xargs nix-store --query --requisites <"$work/roots" | sort -u >"$work/closure"
leaked=$(comm -12 "$work/closure" "$work/unfree")
if [ -n "$leaked" ]; then
  echo "::error::Refusing to push, the closure contains unfree packages:"
  echo "$leaked"
  exit 1
fi

echo "Pushing the closures of:"
cat "$work/roots"
if [ -z "${DRY_RUN:-}" ]; then
  cachix push "$cache" <"$work/roots"
fi
