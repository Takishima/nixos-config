{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.autoUpgrade;
  inherit (config.my.alerts.healthchecksIo) ping;
  bootAttempts = 3;
  rollbackAttempts = 2;
  skipDays = 7;
  report = "/var/lib/nixos-upgrade/report";
  # The checks, then a rollback, which is another switch.
  checksAndRollbackSeconds = cfg.settleSeconds + cfg.retrySeconds + 1800;

  # The files outlive an upgrade: the next system's script reads what this
  # one wrote. Keep their meaning when changing them.
  upgradeHealth = pkgs.writeShellApplication {
    name = "nixos-upgrade-health";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.iproute2
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
      bootsWithoutPassing=$state/boots
      failedAfterReboot=$state/bad
      failuresInARow=$state/strikes
      bootsAfterRollback=$state/returns

      mkdir -p "$state"
      current=$(readlink -f /run/current-system)

      runCheck() {
        local exempt=$1 name=$2 command=$3 output
        if [ -e "$exempt" ] && grep -qxF -e "$name" "$exempt"; then return; fi
        if ! output=$(timeout 60 ${pkgs.runtimeShell} -c "$command" 2>&1); then
          failed+="$name"$'\n'
          failures+="check failed: $name $output"$'\n'
        fi
      }

      # Sets `failed` to the names of the checks that fail, except those
      # listed in the file $1, and `failures` to what they printed.
      runChecks() {
        failed=""
        failures=""
        ${lib.concatStrings (
          lib.mapAttrsToList (name: command: ''
            runCheck "$1" ${
              lib.escapeShellArgs [
                name
                command
              ]
            }
          '') cfg.checks
        )}
        [ -z "$failures" ]
      }

      healthy() {
        local exemptChecks=$1 deadline=$((SECONDS + ${toString cfg.retrySeconds}))
        sleep ${toString cfg.settleSeconds}
        until runChecks "$exemptChecks"; do
          if [ "$SECONDS" -ge "$deadline" ]; then
            printf %s "$failures"
            return 1
          fi
          sleep 15
        done
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

      remember() {
        local failedFirst
        echo "$current" > "$systemBefore"

        rm -f "$failingBefore"
        if ! runChecks /dev/null; then
          failedFirst=$failed
          sleep 15
          if ! runChecks /dev/null && grep -xF -f <(printf %s "$failedFirst") <<<"$failed" > "$failingBefore"; then
            echo "already failing before the upgrade, so not held against it:"
            cat "$failingBefore"
          else
            rm -f "$failingBefore"
          fi
        fi

        if [ ! -e "$goodLink" ] || ! { is "$current" "$awaitingReboot" || is "$current" "$failedAfterReboot"; }; then
          ln -sfn "$current" "$goodLink"
        fi
      }

      # Runs when the upgrade ends, whether it failed or not.
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
          if "$good/bin/switch-to-configuration" switch; then
            rm -f "$awaitingReboot"
          else
            "$good/bin/switch-to-configuration" test
          fi
          echo "rolled back to $good:"
          printf %s "$failures"
          exit 1
        fi

        if [ "$new" = "$current" ] || [ ! -x "$new/bin/switch-to-configuration" ]; then
          if is "$current" "$failedAfterReboot"; then
            echo "still running $current, which failed its checks"
            exit 1
          fi
          if ! healthy /dev/null; then
            echo "$current fails its checks, and there is no upgrade to roll back:"
            printf %s "$failures"
            exit 1
          fi
          exit 0
        fi

        # The new system needs a reboot, which nixos-upgrade may have scheduled.
        if skipped "$new"; then
          echo "$new failed its checks after a reboot, twice: staying on $good"
          if ! shutdown -c; then echo "no reboot was scheduled"; fi
          if ! { nix-env --profile "$profile" --set "$good" && "$good/bin/switch-to-configuration" boot; }; then
            echo "could not make $good the boot default again"
          fi
          exit 1
        fi
        rm -f "$bootsWithoutPassing"
        if ! echo "$new" > "$awaitingReboot"; then
          echo "could not record $new: it will not be checked after the reboot"
          exit 1
        fi
      }

      confirm() {
        local boots good reason
        # A system switched to by hand is not judged.
        if [ "$(readlink -f /run/booted-system)" != "$current" ]; then exit 0; fi
        if ! is "$current" "$failedAfterReboot"; then rm -f "$bootsAfterRollback"; fi

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
        if is "$current" "$awaitingReboot"; then
          if is "$current" "$failedAfterReboot"; then
            echo $(($(count "$failuresInARow") + 1)) > "$failuresInARow"
          else
            echo 1 > "$failuresInARow"
          fi
        fi
        echo "$current" > "$failedAfterReboot"

        # $awaitingReboot stays until the rollback holds, so that a boot
        # after a rollback cut short checks again.
        if nix-env --profile "$profile" --set "$good" && "$good/bin/switch-to-configuration" boot; then
          rm -f "$awaitingReboot" "$bootsWithoutPassing"
          {
            echo "$current failed its checks after the reboot. Rolled back to $good."
            printf '%s\n' "$reason"
          } > ${report}
          systemctl --no-block reboot
        else
          echo "could not make $good the boot default: switching to it without a reboot"
          "$good/bin/switch-to-configuration" test
        fi
        exit 1
      }

      "$1"
    '';
  };
in
{
  imports = [ ./alerts/healthchecks-io.nix ];

  options.my.autoUpgrade = {
    enable = lib.mkEnableOption "switching to the flake's current system on a timer";

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:takishima/nixos-config/rpi";
      description = ''
        The flake to follow; the system is its `nixosConfigurations.<hostname>`.
        One anybody can read, as the machine fetches it without credentials.
        The default is the branch CI moves to a commit of `main` once the
        cache has its builds.
      '';
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "03:30";
      description = "When to upgrade, as a systemd calendar expression (systemd.time(7)).";
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to reboot after an upgrade that brought a new kernel, within
        `rebootWindow` only. Without it the new kernel waits for a reboot by
        hand.
      '';
    };

    checks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        sshd = "systemctl is-active --quiet sshd.service";
      };
      description = ''
        Named shell commands that must all succeed after an upgrade, whether
        it switched the running system or rebooted for a new kernel. Each
        command may take up to a minute, and finds coreutils, grep, iproute2,
        systemd and Nix on its `PATH`. If one keeps failing for
        `retrySeconds`, the machine rolls back to the previous system,
        rebooting if the upgrade did. A check that already fails before
        the upgrade, twice 15 seconds apart, does not count. docs/automatic-upgrades.md says when
        an upgrade is tried again.
      '';
    };

    settleSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 30;
      description = "Seconds to wait after the switch or boot before running `checks`.";
    };

    retrySeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 600;
      description = ''
        How long to keep retrying failed `checks`, every 15 seconds, before
        rolling back. The default leaves time for a slow network to come up.
      '';
    };

    rebootWindow = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        lower = "03:00";
        upper = "05:30";
      };
      description = "The hours a reboot may happen in, as `lower` and `upper`, each `HH:MM`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.optional (cfg.checks != { } && cfg.allowReboot) {
      assertion = lib.all (step: lib.hasInfix step config.systemd.services.nixos-upgrade.script) [
        "nixos-rebuild boot"
        "shutdown -r +1"
      ];
      message = ''
        my.autoUpgrade: the nixos-upgrade service of nixpkgs no longer runs
        `nixos-rebuild boot` and then `shutdown -r +1`. The checks rely on
        both to record an upgrade before its reboot: adapt
        modules/nixos/auto-upgrade.nix.
      '';
    };

    my.alerts.healthchecksIo = {
      units = [ "nixos-upgrade" ] ++ lib.optional (cfg.checks != { }) "nixos-upgrade-confirm";
      heartbeat = [ "nixos-upgrade" ];
    };

    system.autoUpgrade = {
      enable = true;
      flake = "${cfg.flake}#${config.networking.hostName}";
      inherit (cfg) dates allowReboot rebootWindow;
      randomizedDelaySec = "30min";
    };

    systemd.services = lib.mkIf (cfg.checks != { }) {
      nixos-upgrade = {
        after = [ "nixos-upgrade-confirm.service" ];
        serviceConfig = {
          # A run that hangs would block every later one, and report nothing.
          TimeoutStartSec = "12h";
          ExecStartPre = "${lib.getExe upgradeHealth} remember";
          ExecStopPost = "${lib.getExe upgradeHealth} verify";
          TimeoutStopSec = checksAndRollbackSeconds;
        };
      };

      # Not after the network: it has to run even if that never comes up.
      nixos-upgrade-confirm = {
        description = "Check the system an upgrade rebooted into";
        wantedBy = [ "multi-user.target" ];
        # A switch must neither run it again nor stop it during a rollback.
        restartIfChanged = false;
        unitConfig.X-StopOnRemoval = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe upgradeHealth} confirm";
          TimeoutStartSec = checksAndRollbackSeconds;
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
