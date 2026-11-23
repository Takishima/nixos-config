# my.autoUpgrade.checks: an upgrade that fails its checks is undone, one that
# passes them is kept. The upgrade itself is stood in for by a specialisation.
{ self, lib, ... }:
{
  name = "auto-upgrade";

  nodes.machine = {
    imports = [ self.nixosModules.auto-upgrade ];

    my.autoUpgrade = {
      enable = true;
      checks = [ "test -e /run/healthy" ];
      settleSeconds = 1;
    };

    specialisation.next.configuration.environment.etc."next".text = "next";
  };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.machine.systemd.services.nixos-upgrade.serviceConfig) ExecStartPre ExecStopPost;
    in
    ''
      machine.wait_for_unit("multi-user.target")
      original = machine.succeed("readlink /run/current-system").strip()
      upgrade = "/run/current-system/specialisation/next/bin/switch-to-configuration test"

      with subtest("nothing happens when the system did not change"):
          machine.succeed("${ExecStartPre}", "${ExecStopPost}")

      with subtest("an upgrade that fails its checks is undone"):
          machine.succeed("${ExecStartPre}", upgrade, "test -e /etc/next")
          machine.fail("${ExecStopPost}")
          assert machine.succeed("readlink /run/current-system").strip() == original
          assert machine.succeed("readlink -f /nix/var/nix/profiles/system").strip() == original
          machine.fail("test -e /etc/next")

      with subtest("an upgrade that passes them is kept"):
          machine.succeed("touch /run/healthy", "${ExecStartPre}", upgrade, "${ExecStopPost}")
          machine.succeed("test -e /etc/next")
    '';
}
