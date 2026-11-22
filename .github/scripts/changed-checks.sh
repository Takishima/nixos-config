#!/usr/bin/env bash
# Lists the flake checks whose derivation differs from the one in another
# revision of this flake, as JSON: { "<system>": [ "<check>", ... ] }.
# Usage: changed-checks.sh <base flake ref>
#
# Comparing derivations and not file names follows what a change reaches: a
# shared module rebuilds every host that imports it, a host's own file only
# that host, and the README neither.
set -euo pipefail

base_ref=$1
drvs='builtins.mapAttrs (_: builtins.mapAttrs (_: check: check.drvPath))'

head=$(nix eval --json .#checks --apply "$drvs")

# A base that does not evaluate has nothing to compare with: build everything.
if ! base=$(nix eval --json "$base_ref#checks" --apply "$drvs"); then
  echo "::warning::$base_ref does not evaluate, so every check counts as changed." >&2
  base='{}'
fi

jq -cn --argjson head "$head" --argjson base "$base" '
  $head | with_entries(
    .key as $system
    | .value |= (to_entries | map(select(.value != $base[$system][.key]) | .key))
  )'
