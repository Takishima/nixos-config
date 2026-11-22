# NixOS VM tests of the modules, exposed as `checks.<system>.vm-<name>`.
#
#   nix build .#checks.x86_64-linux.vm-ssh-server -L
#   nix run .#checks.x86_64-linux.vm-ssh-server.driverInteractive
{
  self,
  nixpkgs,
  pkgs,
}:
let
  inherit (nixpkgs) lib;

  # `lib.nixos.runTest` and not `pkgs.testers.runNixOSTest`: the latter hands
  # the nodes a read-only pkgs, where the modules' own nixpkgs.overlays and
  # nixpkgs.config would not apply.
  run =
    file:
    lib.nixos.runTest {
      imports = [ file ];
      hostPkgs = pkgs;
      _module.args = {
        inherit self;
        # Throwaway keys from nixpkgs' own tests, so none is committed here.
        sshKeys = import "${nixpkgs}/nixos/tests/ssh-keys.nix" pkgs;
      };
    };

  tests = lib.filterAttrs (file: _: lib.hasSuffix ".nix" file && file != "default.nix") (
    builtins.readDir ./.
  );
in
lib.mapAttrs' (
  file: _: lib.nameValuePair "vm-${lib.removeSuffix ".nix" file}" (run (./. + "/${file}"))
) tests
