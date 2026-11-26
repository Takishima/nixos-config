# my.postSwitch without my.autoRollback: a specialisation stands in for the new system.
{ self, ... }:
{
  name = "post-switch";

  nodes.machine = {
    imports = [ self.nixosModules.post-switch ];

    my.postSwitch = {
      checks.works = "test ! -e /etc/broken";
      settleSeconds = 1;
      retrySeconds = 0;
    };

    specialisation = {
      next.configuration.environment.etc."next".text = "next";
      broken.configuration.environment.etc."broken".text = "broken";
    };
  };

  # As a host where no module names a check. Only evaluated.
  nodes.unchecked.imports = [ self.nixosModules.post-switch ];

  testScript =
    { nodes, ... }:
    assert !(nodes.unchecked.system.preSwitchChecks ? post-switch-checks);
    ''
      unit = "post-switch-checks.service"

      def switch_to(specialisation):
          """Switches as `nixos-rebuild test` does: how the checks that follow ended, and their log."""
          machine.succeed(f"/run/booted-system/specialisation/{specialisation}/bin/switch-to-configuration test")
          machine.wait_until_succeeds(f"systemctl show -p ActiveState --value {unit} | grep -qxE 'inactive|failed'")
          return machine.succeed(f"journalctl -u {unit} -n 20 --no-pager")

      machine.wait_for_unit("multi-user.target")

      with subtest("a switch that passes its checks says nothing"):
          checks = switch_to("next")
          machine.succeed("test -e /etc/next")
          assert "check failed" not in checks and "Failed" not in checks, checks

      with subtest("a switch that fails a check is reported, and stays"):
          checks = switch_to("broken")
          assert "check failed: works" in checks and "Failed" in checks, checks
          machine.succeed("test -e /etc/broken")

      with subtest("a check that already failed is not held against the next switch"):
          checks = switch_to("broken")
          assert checks.count("check failed: works") == 1, checks
    '';
}
