# my.autoUpgrade with my.autoRollback, and the real units: the upgrade is what the
# test writes to /run/upgrade, and a specialisation stands in for the new system.
{ lib, self, ... }:
{
  name = "auto-upgrade";

  nodes.machine = {
    imports = [
      self.nixosModules.auto-rollback
      self.nixosModules.auto-upgrade
    ];

    my = {
      autoUpgrade = {
        enable = true;
        # No reboot by the stand-in below: the test sets up each reboot itself.
        allowReboot = false;
      };
      autoRollback.enable = true;
      postSwitch = {
        checks = {
          healthy = "test -e /run/healthy";
          other = "test ! -e /run/other-broken";
          recorded = "test ! -e /run/watch || cat /var/lib/nixos-upgrade/pending > /run/seen";
          failsOnce = "if [ -e /run/fail-once ]; then rm /run/fail-once; false; fi";
          failsLater = "if [ -e /run/fail-later ]; then if [ -e /run/sampled ]; then false; else touch /run/sampled; fi; fi";
        };
        settleSeconds = 1;
        retrySeconds = 0;
      };
    };

    systemd.services = {
      nixos-upgrade.script = lib.mkForce "if [ -e /run/upgrade ]; then . /run/upgrade; fi";
      # Started by the test, not by the boot: the VM always boots the same
      # system, so a rollback cannot get away from it as on a real machine.
      nixos-upgrade-confirm.wantedBy = lib.mkForce [ ];
    };

    specialisation.next.configuration.environment.etc."next".text = "next";
  };

  testScript = ''
    profile = "/nix/var/nix/profiles/system"
    state = "/var/lib/nixos-upgrade"
    good = "/nix/var/nix/gcroots/nixos-upgrade-good"

    def current():
        return machine.succeed("readlink -f /run/current-system").strip()

    def link(path):
        return machine.succeed(f"readlink -f {path}").strip()

    def read(file):
        return machine.succeed(f"cat {state}/{file}").strip()

    def upgrade(command):
        """Runs nixos-upgrade.service with this as the upgrade: whether it succeeded, and its log."""
        machine.succeed(f"echo '{command}' > /run/upgrade")
        machine.execute("systemctl start nixos-upgrade.service")
        machine.wait_until_succeeds(
            "systemctl show -p ActiveState --value nixos-upgrade.service | grep -qxE 'inactive|failed'"
        )
        result = machine.succeed("systemctl show -p Result --value nixos-upgrade.service").strip()
        return result == "success", machine.succeed("journalctl -u nixos-upgrade.service -n 30 --no-pager")

    def succeeds(command):
        ok, log = upgrade(command)
        assert ok, log

    def fails(command):
        ok, log = upgrade(command)
        assert not ok, log

    def same(actual, wanted):
        assert actual == wanted, f"{actual}, not {wanted}"

    machine.wait_for_unit("multi-user.target")
    original = current()
    switch_to_next = f"{original}/specialisation/next/bin/switch-to-configuration test"

    with subtest("nothing happens when the system did not change"):
        machine.succeed("touch /run/healthy")
        succeeds("true")
        same(current(), original)

    with subtest("a check that fails only the first time before the upgrade still counts"):
        machine.succeed("touch /run/fail-once")
        succeeds("true")
        machine.fail(f"test -e {state}/failing-before")

    with subtest("a check that fails only the second time before the upgrade still counts"):
        machine.succeed("touch /run/other-broken /run/fail-later")
        upgrade("true")
        same(read("failing-before"), "other")
        machine.succeed("rm /run/other-broken /run/fail-later /run/sampled")

    with subtest("a system that fails its checks is reported, with nothing to roll back"):
        machine.succeed("rm /run/healthy")
        ok, log = upgrade("true")
        assert not ok and "check failed: healthy" in log, log
        same(current(), original)

    with subtest("an upgrade that fails its checks is rolled back"):
        machine.succeed("touch /run/healthy")
        fails(f"rm /run/healthy; {switch_to_next}")
        same(current(), original)
        same(link(profile), original)
        machine.fail("test -e /etc/next")

    with subtest("a system switched to is recorded for the next boot while it is checked"):
        machine.succeed("touch /run/healthy")
        succeeds(f"touch /run/watch; {switch_to_next}")
        same(machine.succeed("cat /run/seen").strip(), current())
        machine.fail(f"test -e {state}/pending")
        machine.succeed("rm /run/watch", f"{original}/bin/switch-to-configuration test")

    with subtest("a check that already failed before is not held against it"):
        machine.succeed("touch /run/healthy /run/other-broken")
        succeeds(switch_to_next)
        machine.succeed("test -e /etc/next", "rm /run/other-broken")
        other = current()
        assert other != original, other
        same(link(good), other)

    # An upgrade that needs a reboot only sets the system profile. The VM always
    # boots `original`, so that plays the new system and `other` the one before.
    install_original = f"nix-env --profile {profile} --set {original}"

    def run_previous():
        machine.succeed(f"{other}/bin/switch-to-configuration test")

    def booted_upgrade():
        """As after the reboot of an upgrade from `other` to `original`."""
        machine.succeed(f"{original}/bin/switch-to-configuration test")
        machine.succeed(f"ln -sfn {other} {good}", f"echo {original} > {state}/pending")

    def confirm_rolls_back():
        machine.succeed("systemctl restart --no-block nixos-upgrade-confirm.service")
        machine.wait_for_shutdown()
        machine.start()
        machine.wait_for_unit("multi-user.target")
        same(link(profile), other)
        same(read("bad"), original)
        machine.fail(f"test -e {state}/pending")

    with subtest("an upgrade that needs a reboot is recorded"):
        run_previous()
        succeeds(install_original)
        same(read("pending"), original)
        same(link(good), other)

    with subtest("after the reboot, it is kept if it passes its checks"):
        booted_upgrade()
        machine.succeed("systemctl restart nixos-upgrade-confirm.service")
        same(link(good), original)
        machine.fail(f"test -e {state}/pending")

    with subtest("it is rolled back with a reboot if it fails them"):
        booted_upgrade()
        machine.succeed("rm /run/healthy")
        confirm_rolls_back()
        same(read("strikes"), "1")
        assert "check failed: healthy" in read("report"), read("report")

    with subtest("after one failure it is tried again"):
        run_previous()
        succeeds(install_original)
        same(read("pending"), original)

    with subtest("it is rolled back if it boots too many times without passing"):
        booted_upgrade()
        machine.succeed("touch /run/healthy", f"echo 3 > {state}/boots")
        confirm_rolls_back()
        same(read("strikes"), "2")

    with subtest("after two failures in a row it is skipped, for a week"):
        run_previous()
        fails(install_original)
        same(link(profile), other)
        machine.fail(f"test -e {state}/pending")

        machine.succeed(f"touch -d '8 days ago' {state}/bad")
        succeeds(install_original)
        same(read("pending"), original)
        machine.succeed(f"rm {state}/pending", f"nix-env --profile {profile} --set {other}")

    with subtest("a rollback that did not hold is tried again, but not forever, and is no new failure"):
        # `original` is booted and is the system that failed.
        machine.succeed(f"{original}/bin/switch-to-configuration test", f"echo 2 > {state}/returns")
        machine.fail("systemctl restart nixos-upgrade-confirm.service")
        machine.succeed(f"rm {state}/returns")
        strikes = read("strikes")
        confirm_rolls_back()
        same(read("strikes"), strikes)

    with subtest("the upgrade that replaces a system that failed is recorded"):
        # `original` is booted again, and still the system that failed.
        replacement = link(f"{original}/specialisation/next")
        succeeds(f"nix-env --profile {profile} --set {replacement}")
        same(read("pending"), replacement)

    with subtest("a rollback that cannot be made is not reported as made"):
        machine.succeed(
            "mkdir -p /run/broken/bin",
            "printf '#!/bin/sh\\nexit 1\\n' > /run/broken/bin/switch-to-configuration",
            "chmod +x /run/broken/bin/switch-to-configuration",
            f"ln -sfn /run/broken {good}",
            f"echo {original} > {state}/pending",
            f"rm -f {state}/report {state}/failing-before /run/healthy",
        )
        machine.fail("systemctl restart nixos-upgrade-confirm.service")
        machine.fail(f"test -e {state}/report")
  '';
}
