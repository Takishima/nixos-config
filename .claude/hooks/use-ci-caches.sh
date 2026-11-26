#!/usr/bin/env bash
# Gives the session's Nix commands the binary caches .github/workflows/check.yml uses.
set -euo pipefail

caches=(
  https://dn-personal.cachix.org
  https://nix-community.cachix.org
  https://devenv.cachix.org
)
publicKeys=(
  dn-personal.cachix.org-1:8pB//y1vrWsFfDo9FebVmnMU3mF9t4bDDxaeQPN88RE=
  nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
  devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
)

nixConfig="${NIX_CONFIG:+$NIX_CONFIG
}extra-substituters = ${caches[*]}
extra-trusted-public-keys = ${publicKeys[*]}"

printf 'export NIX_CONFIG=%q\n' "$nixConfig" >>"$CLAUDE_ENV_FILE"
