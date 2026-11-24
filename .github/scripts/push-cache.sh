#!/usr/bin/env bash
# Pushes to the public Cachix cache the free store paths in the closure of
# this system's checks that no cache has signed.
# Usage: push-cache.sh <cache> <system>; DRY_RUN=1 only lists.
#
# cachix pushes a path with its whole closure, so a path whose closure
# reaches an unfree package is left out.
set -euo pipefail
export LC_ALL=C

cache=$1
system=$2
here=$(dirname "$0")

# Not worth pushing. The two checks are rebuilt on every commit.
skip='-(source|user-environment|treefmt-check|statix)$'

# Unfree packages a free one wraps, which unfree-paths.nix cannot see.
hidden='copilot-language-server-[0-9]'

# A path none of these signed was built for this flake, by this run or by a
# pull request on nixbuild.net.
cached="(cache[.]nixos[.]org|nix-community[.]cachix[.]org|devenv[.]cachix[.]org|${cache}[.]cachix[.]org)-1:"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# nix flake check does not fetch a check that a cache already has.
nix eval --json ".#checks.$system" --apply builtins.attrNames |
  jq -r --arg system "$system" '.[] | ".#checks.\($system).\(.)"' |
  xargs -r nix build --no-link --print-out-paths |
  nix path-info --recursive --sigs --stdin >"$work/signatures"

awk '{ print $1 }' "$work/signatures" | sort -u >"$work/closure"
awk -v cached="[[:space:]]$cached" -v skip="$skip" \
  '$0 !~ cached && $1 !~ skip { print $1 }' "$work/signatures" | sort -u >"$work/candidates"

nix eval --json .#nixosConfigurations --apply "
  hosts:
  let
    unfree = ($(cat "$here/unfree-paths.nix"));
    here = builtins.filter (host: host.config.nixpkgs.hostPlatform.system == \"$system\") (builtins.attrValues hosts);
  in
  builtins.concatMap (host: unfree host.config) here
" | jq -r '.[]' | sort -u >"$work/unfree"

{
  comm -12 "$work/closure" "$work/unfree"
  grep -E "^/nix/store/[a-z0-9]{32}-$hidden" "$work/closure" || true
} | xargs -r nix-store --query --referrers-closure | sort -u >"$work/tainted"

comm -12 "$work/candidates" "$work/tainted" |
  sed 's/^/Not pushed, its closure holds an unfree package: /'
comm -23 "$work/candidates" "$work/tainted" >"$work/roots"

if [ ! -s "$work/roots" ]; then
  echo "Nothing to push."
  exit 0
fi

echo "Pushing the closures of:"
cat "$work/roots"
if [ -z "${DRY_RUN:-}" ]; then
  cachix push "$cache" <"$work/roots"
fi
