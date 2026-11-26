# Goes back to the system before when a switch or an upgrade fails
# my.postSwitch.checks, with a reboot if the upgrade rebooted.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.autoRollback;
  inherit (config.my) autoUpgrade postSwitch;
  inherit (config.my.alerts.healthchecksIo) ping;
  bootAttempts = 3;
  rollbackAttempts = 2;
  skipDays = 7;
  report = "/var/lib/nixos-upgrade/report";

  # The files outlive an upgrade: the next system's script reads what this
  # one wrote. Keep their meaning when changing them.
  upgradeHealth = pkgs.writeShellApplication {
    name = "nixos-upgrade-health";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
      config.nix.package.out
    ];
    # Not errexit: a rollback goes on past a step that fails.
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = ''
      profile=/nix/var/nix/profiles/system
      state=/var/lib/nixos-upgrade
      systemBefore=/run/nixos-upgrade-previous
      failingBefore=$state/failing-before
      # A garbage collector root, so the system to roll back to stays.
      goodLink=/nix/var/nix/gcroots/nixos-upgrade-good
      awaitingReboot=$state/pending
      rebootedFor=$state/rebooted
      bootsWithoutPassing=$state/boots
      failedAfterReboot=$state/bad
      failuresInARow=$state/strikes
      bootsAfterRollback=$state/returns

      mkdir -p "$state"
      current=$(readlink -f /run/current-system)

      # Sets `failures` to what the failing checks print. The file $1 lists the exempt.
      healthy() {
        failures=$(${postSwitch.run} healthy "$1")
      }

      # NIXOS_NO_CHECK: nothing holds a rollback up, or judges it in its turn.
      activate() {
        NIXOS_NO_CHECK=1 "$1/bin/switch-to-configuration" "$2"
      }

      is() {
        [ -e "$2" ] && [ "$1" = "$(cat "$2")" ]
      }

      count() {
        if [ -e "$1" ]; then cat "$1"; else echo 0; fi
      }

      # One failure may be a network outage: only the second in a row counts.
      skipped() {
        is "$1" "$failedAfterReboot" && [ "$(count "$failuresInARow")" -ge 2 ] \
          && [ $(($(date +%s) - $(stat -c %Y "$failedAfterReboot"))) -lt ${toString (skipDays * 86400)} ]
      }

      # Counts against the system $1 that it failed after a reboot.
      strike() {
        if is "$1" "$failedAfterReboot"; then
          echo $(($(count "$failuresInARow") + 1)) > "$failuresInARow"
        else
          echo 1 > "$failuresInARow"
        fi
        echo "$1" > "$failedAfterReboot"
      }

      remember() {
        echo "$current" > "$systemBefore"
        ${postSwitch.run} sample "$failingBefore"

        if [ ! -e "$goodLink" ] || ! { is "$current" "$awaitingReboot" || is "$current" "$failedAfterReboot"; }; then
          ln -sfn "$current" "$goodLink"
        fi
      }

      # Runs when a switch or an upgrade ends, whether it failed or not.
      verify() {
        local before good new
        before=$(cat "$systemBefore") || exit 0
        good=$(readlink "$goodLink") || exit 0
        new=$(readlink -f "$profile")

        if [ "$current" != "$before" ]; then
          # It is already the boot default: a reset now leaves it to confirm.
          echo "$current" > "$awaitingReboot"
          if healthy "$failingBefore"; then
            ln -sfn "$current" "$goodLink"
            rm -f "$awaitingReboot" "$bootsWithoutPassing"
            exit 0
          fi
          echo "the upgraded system fails its checks: rolling back to $good"
          if ! nix-env --profile "$profile" --set "$good"; then
            echo "could not reset the system profile"
          fi
          # The running system matters more than the boot loader.
          if activate "$good" switch; then
            rm -f "$awaitingReboot"
          else
            activate "$good" test
          fi
          echo "rolled back to $good:"
          printf '%s\n' "$failures"
          exit 1
        fi

        if [ "$new" = "$current" ] || [ ! -x "$new/bin/switch-to-configuration" ]; then
          if is "$current" "$failedAfterReboot"; then
            echo "still running $current, which failed its checks"
            exit 1
          fi
          if ! healthy /dev/null; then
            echo "$current fails its checks, and there is no upgrade to roll back:"
            printf '%s\n' "$failures"
            exit 1
          fi
          exit 0
        fi

        # The new system needs a reboot, which nixos-upgrade may have scheduled.
        if skipped "$new"; then
          echo "$new failed its checks after a reboot, twice: staying on $good"
          if ! shutdown -c; then echo "no reboot was scheduled"; fi
          if ! { nix-env --profile "$profile" --set "$good" && activate "$good" boot; }; then
            echo "could not make $good the boot default again"
          fi
          exit 1
        fi
        rm -f "$bootsWithoutPassing"
        if ! echo "$new" > "$awaitingReboot"; then
          echo "could not record $new: it will not be checked after the reboot"
          exit 1
        fi
        if [ -e /run/systemd/shutdown/scheduled ]; then
          echo "$new" > "$rebootedFor"
        else
          rm -f "$rebootedFor"
        fi
      }

      confirm() {
        local awaited boots good reason
        # A system switched to by hand is not judged.
        if [ "$(readlink -f /run/booted-system)" != "$current" ]; then exit 0; fi
        if ! is "$current" "$failedAfterReboot"; then rm -f "$bootsAfterRollback"; fi

        awaited=""
        if [ -e "$awaitingReboot" ]; then awaited=$(cat "$awaitingReboot"); fi
        # A boot loader that tries a system once started the one before instead.
        if [ -n "$awaited" ] && [ "$awaited" != "$current" ] && is "$awaited" "$rebootedFor"; then
          echo "$awaited did not come up after its reboot: this is $current again"
          strike "$awaited"
          rm -f "$awaitingReboot" "$bootsWithoutPassing" "$rebootedFor"
          if ! { nix-env --profile "$profile" --set "$current" && activate "$current" boot; }; then
            echo "could not make $current the boot default again"
          fi
          exit 1
        fi

        if is "$current" "$awaitingReboot"; then
          boots=$(($(count "$bootsWithoutPassing") + 1))
          echo "$boots" > "$bootsWithoutPassing"
          sync "$bootsWithoutPassing"

          if [ "$boots" -gt ${toString bootAttempts} ]; then
            reason="booted ${toString bootAttempts} times without passing its checks"
          elif healthy "$failingBefore"; then
            ln -sfn "$current" "$goodLink"
            rm -f "$awaitingReboot" "$bootsWithoutPassing" "$failedAfterReboot" "$failuresInARow"
            exit 0
          else
            reason=$failures
          fi
        elif is "$current" "$failedAfterReboot"; then
          # The rollback was cut short, or the boot loader ignores it.
          boots=$(($(count "$bootsAfterRollback") + 1))
          echo "$boots" > "$bootsAfterRollback"
          sync "$bootsAfterRollback"
          if [ "$boots" -gt ${toString rollbackAttempts} ]; then
            echo "booted $current again and again, although it failed its checks: staying on it"
            exit 1
          fi
          reason="it failed its checks before, and was booted again"
        else
          exit 0
        fi

        good=""
        if [ -e "$goodLink" ]; then good=$(readlink "$goodLink"); fi
        if [ ! -x "$good/bin/switch-to-configuration" ] || [ "$good" = "$current" ]; then
          echo "$current fails its checks, and there is no system to roll back to:"
          printf '%s\n' "$reason"
          exit 1
        fi

        echo "$current fails its checks: rebooting into $good"
        printf '%s\n' "$reason"
        if is "$current" "$awaitingReboot"; then strike "$current"; fi

        # $awaitingReboot stays until the rollback holds, so that a boot
        # after a rollback cut short checks again.
        if nix-env --profile "$profile" --set "$good" && activate "$good" boot; then
          rm -f "$awaitingReboot" "$bootsWithoutPassing"
          {
            echo "$current failed its checks after the reboot. Rolled back to $good."
            printf '%s\n' "$reason"
          } > ${report}
          systemctl --no-block reboot
        else
          echo "could not make $good the boot default: switching to it without a reboot"
          activate "$good" test
        fi
        exit 1
      }

      "$1"
    '';
  };
in
{
  imports = [
    ./alerts/healthchecks-io.nix
    ./auto-upgrade.nix
    ./post-switch.nix
  ];

  options.my.autoRollback.enable = lib.mkEnableOption ''
    going back to the system before when a `nixos-rebuild switch` or `test`,
    or an upgrade of `my.autoUpgrade`, fails `my.postSwitch.checks`. An
    upgrade that rebooted for a new kernel is checked after the reboot, and
    undone with another. docs/automatic-upgrades.md says when an upgrade is
    tried again'';

  config = lib.mkIf cfg.enable {
    assertions = lib.optional (autoUpgrade.enable && autoUpgrade.allowReboot) {
      assertion = lib.all (step: lib.hasInfix step config.systemd.services.nixos-upgrade.script) [
        "nixos-rebuild boot"
        "shutdown -r +1"
      ];
      message = ''
        my.autoRollback: the nixos-upgrade service of nixpkgs no longer runs
        `nixos-rebuild boot` and then `shutdown -r +1`. The checks rely on
        both to record an upgrade before its reboot: adapt
        modules/nixos/auto-rollback.nix.
      '';
    };

    my = {
      postSwitch = {
        remember = "${lib.getExe upgradeHealth} remember";
        verify = "${lib.getExe upgradeHealth} verify";
      };
      alerts.healthchecksIo.units = [ "nixos-upgrade-confirm" ];
    };

    systemd.services = {
      # Not after the network: it has to run even if that never comes up.
      nixos-upgrade-confirm = {
        description = "Check the system an upgrade rebooted into";
        wantedBy = [ "multi-user.target" ];
        before = [ "nixos-upgrade.service" ];
        # A switch must neither run it again nor stop it during a rollback.
        restartIfChanged = false;
        unitConfig.X-StopOnRemoval = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe upgradeHealth} confirm";
          TimeoutStartSec = postSwitch.verifyTimeoutSeconds;
        };
      };

      # A rollback that reboots has no time to report: the next boot does.
      nixos-upgrade-report = lib.mkIf (ping != null) {
        description = "Report an upgrade that was rolled back with a reboot";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.ConditionPathExists = report;
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = "10min";
        };
        script = ''
          ${ping} /fail "an upgrade was rolled back" < ${report}
          rm ${report}
        '';
      };
    };
  };
}
