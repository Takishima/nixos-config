#!/usr/bin/env bash
# Pushes to the public Cachix cache the free store paths in the closure of
# this system's checks that no public cache has.
# Usage: push-cache.sh <cache> <system>; DRY_RUN=1 only lists.
#
# cachix pushes a path with its whole closure, so a path built from an unfree
# package is left out.
set -euo pipefail
export LC_ALL=C

cache=$1
system=$2
here=$(dirname "$0")

# Not worth pushing. The two checks are rebuilt on every commit.
skip='-(source|user-environment|treefmt-check|statix)$'

# Unfree packages a free one wraps, which unfree-derivations.nix cannot see.
hidden='copilot-language-server-[0-9]'

public="https://cache.nixos.org https://nix-community.cachix.org https://devenv.cachix.org https://$cache.cachix.org"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

nix eval --json ".#checks.$system" --apply builtins.attrNames |
  jq -r --arg system "$system" '.[] | ".#checks.\($system).\(.)"' >"$work/checks"

# A dry run names the derivations to build and the paths to fetch, and
# downloads neither.
plan() {
  if ! xargs -r nix build --dry-run --json "$@" <"$work/checks" >"$work/outputs.json" 2>"$work/plan"; then
    cat "$work/plan" >&2
    return 1
  fi
  sed -n 's|^  \(/nix/store/.*\)$|\1|p' "$work/plan" | sort -u
}

plan --option substituters "$public" >"$work/without-builder"
sed -n '/[.]drv$/p' "$work/without-builder" >"$work/unbuilt"
plan >"$work/with-builder"
sed '/[.]drv$/d' "$work/with-builder" >"$work/fetchable"

jq -r '.[].drvPath' "$work/outputs.json" | xargs -r nix-store --query --requisites | sort -u >"$work/built-from"
jq -r '.[].outputs[]' "$work/outputs.json" | while read -r output; do
  if nix-store --check-validity "$output" 2>/dev/null; then echo "$output"; fi
done | xargs -r nix-store --query --requisites | sort -u - "$work/fetchable" >"$work/closure"

nix eval --json .#nixosConfigurations --apply "
  hosts:
  let
    unfree = ($(cat "$here/unfree-derivations.nix"));
    here = builtins.filter (host: host.config.nixpkgs.hostPlatform.system == \"$system\") (builtins.attrValues hosts);
  in
  builtins.concatMap (host: unfree host.config) here
" | jq -r '.[]' | sort -u >"$work/unfree"

{
  comm -12 "$work/built-from" "$work/unfree"
  grep -E "^/nix/store/[a-z0-9]{32}-$hidden.*[.]drv$" "$work/built-from" || true
} | xargs -r nix-store --query --referrers-closure | sort -u >"$work/tainted"

in_closure() {
  xargs -r nix-store --query --outputs | sort -u | comm -12 - "$work/closure"
}

comm -12 "$work/unbuilt" "$work/tainted" | in_closure |
  sed 's/^/Not pushed, built from an unfree package: /'
comm -23 "$work/unbuilt" "$work/tainted" | in_closure | sed -E "/$skip/d" >"$work/roots"

if [ ! -s "$work/roots" ]; then
  echo "Nothing to push."
  exit 0
fi

echo "Pushing the closures of:"
cat "$work/roots"
if [ -z "${DRY_RUN:-}" ]; then
  xargs nix-store --realise <"$work/roots" >/dev/null
  cachix push "$cache" <"$work/roots"
fi
