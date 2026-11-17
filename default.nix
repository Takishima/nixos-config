# The flake's outputs for nix-build, nix-instantiate and `import`, pinned by flake.lock.
(import (
  let
    inherit ((builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.flake-compat) locked;
  in
  fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  }
) { src = ./.; }).defaultNix
