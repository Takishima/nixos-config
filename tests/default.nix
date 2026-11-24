# NixOS VM tests of the modules, exposed as `checks.<system>.vm-<name>`.
{
  self,
  nixpkgs,
  pkgs,
}:
let
  inherit (nixpkgs) lib;

  # Not `pkgs.testers.runNixOSTest`: its nodes get a read-only pkgs, where
  # the modules' own nixpkgs.overlays and nixpkgs.config would not apply.
  # Throwaway keys from nixpkgs' own tests, so none is committed here.
  sshKeys = import "${nixpkgs}/nixos/tests/ssh-keys.nix" pkgs;

  # checkPassword <password> <hash>: whether the hash is of the password.
  checkPassword = pkgs.writeScript "check-password" ''
    #!${lib.getExe pkgs.perl}
    exit(crypt($ARGV[0], $ARGV[1]) eq $ARGV[1] ? 0 : 1);
  '';

  run =
    file:
    lib.nixos.runTest {
      imports = [ file ];
      hostPkgs = pkgs;
      _module.args = {
        inherit
          self
          sshKeys
          checkPassword
          ;
        fixtureSecrets = {
          file = ./fixtures/secrets.yaml;
          sshKeyPath = "${sshKeys.snakeOilEd25519PrivateKey}";
        };
      };
    };

  tests = lib.filterAttrs (file: _: lib.hasSuffix ".nix" file && file != "default.nix") (
    builtins.readDir ./.
  );
in
lib.mapAttrs' (
  file: _: lib.nameValuePair "vm-${lib.removeSuffix ".nix" file}" (run (./. + "/${file}"))
) tests
