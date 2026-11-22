# my.secrets, and the modules gating on it: fixtures/secrets.yaml is encrypted
# to nixpkgs' test SSH key, standing in for the host key, and holds
#   password_hash/alice: yescrypt of "sesame"
#   wifi/home: correct-horse-battery
{
  self,
  sshKeys,
  lib,
  pkgs,
  ...
}:
let
  # checkPassword <password> <hash>: whether the hash is of the password.
  checkPassword = pkgs.writeScript "check-password" ''
    #!${lib.getExe pkgs.perl}
    exit(crypt($ARGV[0], $ARGV[1]) eq $ARGV[1] ? 0 : 1);
  '';
  file = ./fixtures/secrets.yaml;
  wifiPassword = "correct-horse-battery";
in
{
  name = "secrets";

  nodes.machine = {
    imports = [
      self.nixosModules.user
      self.nixosModules.wifi
    ];

    my = {
      user.name = "alice";
      secrets = {
        inherit file;
        sshKeyPath = "${sshKeys.snakeOilEd25519PrivateKey}";
      };
      wifi.networks = {
        home.ssid = "HomeNet";
        # No password in the sops file: no profile.
        cafe.ssid = "Cafe";
      };
    };

    networking.networkmanager.enable = true;
  };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.machine.my.secrets) has;
      expected = {
        "password_hash/alice" = true;
        "password_hash/bob" = false;
        "password_hash" = false;
        "wifi/home" = true;
        "wifi/cafe" = false;
        # A key with nested keys but no value of its own.
        "wifi" = false;
        "nope" = false;
      };
      wrong = lib.filterAttrs (key: value: has key != value) expected;
    in
    assert lib.assertMsg (
      wrong == { }
    ) "my.secrets.has is wrong for: ${toString (lib.attrNames wrong)}";
    ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the password comes from the sops file"):
          shadow = machine.succeed("getent shadow alice").split(":")[1]
          assert shadow.startswith("$y$"), shadow
          assert shadow == machine.succeed("cat /run/secrets-for-users/password_hash/alice").strip()
          machine.succeed(f"${checkPassword} sesame '{shadow}'")
          machine.fail(f"${checkPassword} changeme '{shadow}'")

      with subtest("only the network with a password gets a profile"):
          machine.wait_until_succeeds("nmcli -g NAME connection show | grep -qx HomeNet")
          profiles = machine.succeed("nmcli -g NAME connection show").splitlines()
          assert "HomeNet" in profiles and "Cafe" not in profiles, profiles
          psk = machine.succeed(
              "nmcli -s -g 802-11-wireless-security.psk connection show HomeNet"
          ).strip()
          assert psk == "${wifiPassword}", psk

      with subtest("sops-host decrypts with the SSH key"):
          out = machine.succeed(
              """sops-host decrypt --extract '["wifi"]["home"]' ${file}"""
          ).strip()
          assert out == "${wifiPassword}", out
    '';
}
