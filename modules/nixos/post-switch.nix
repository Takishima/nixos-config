# Runs the checks other modules name after a switch, and reports those that fail.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.postSwitch;
  inherit (config.my.alerts.healthchecksIo) ping;
  unit = "post-switch-checks.service";
  failingBefore = "/run/post-switch-checks-failing-before";
  reportFailure = lib.optionalString (
    ping != null
  ) "--property=OnFailure=healthchecks-fail@${unit}.service";

  checks = pkgs.writeShellApplication {
    name = "post-switch-checks";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.iproute2
      config.systemd.package
      config.nix.package.out
    ];
    text = ''
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

      # Lists in the file $1 the checks that fail twice, before a switch.
      sample() {
        local alreadyFailing=$1 failedFirst
        rm -f "$alreadyFailing"
        if ! runChecks /dev/null; then
          failedFirst=$failed
          sleep 15
          if ! runChecks /dev/null && grep -xF -f <(printf %s "$failedFirst") <<<"$failed" > "$alreadyFailing"; then
            echo "already failing before, so not held against the new system:"
            cat "$alreadyFailing"
          else
            rm -f "$alreadyFailing"
          fi
        fi
      }

      # Fails, and prints why, if a check not listed in the file $1 keeps failing.
      healthy() {
        local exempt=$1 deadline
        sleep ${toString cfg.settleSeconds}
        deadline=$((SECONDS + ${toString cfg.retrySeconds}))
        until runChecks "$exempt"; do
          if [ "$SECONDS" -ge "$deadline" ]; then
            printf %s "$failures"
            return 1
          fi
          sleep 15
        done
      }

      "$@"
    '';
  };

  onSwitch = pkgs.writeShellApplication {
    name = "post-switch-checks-on-switch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      config.systemd.package
    ];
    text = ''
      # A pre-switch check: the switch stops units before anything else can run.
      before() {
        local action=$1 judge
        case $action in
          switch | test) ;;
          *) return ;;
        esac
        # An upgrade judges its own switch, and the checks under way this one too.
        for judge in nixos-upgrade.service ${unit}; do
          case $(systemctl show --property=ActiveState --value "$judge") in
            activating | deactivating) return ;;
          esac
        done
        ${cfg.remember}
        echo "${unit} checks the new system once the switch ends"
        # Transient: systemd still has the units of the system before.
        systemd-run --quiet --no-block --collect --unit=${unit} \
          --property=Type=oneshot --property=TimeoutStartSec=${toString cfg.verifyTimeoutSeconds} \
          --property=Before=nixos-upgrade.service ${reportFailure} "$0" after
      }

      after() {
        # The switch holds this lock until it ends.
        flock /run/nixos/switch-to-configuration.lock true
        exec ${cfg.verify}
      }

      "$@"
    '';
  };
in
{
  imports = [ ./alerts/healthchecks-io.nix ];

  options.my.postSwitch = {
    checks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        sshd = "systemctl is-active --quiet sshd.service";
      };
      description = ''
        Named shell commands that must all succeed after a `nixos-rebuild
        switch` or `test`, and after an upgrade of `my.autoUpgrade`. Modules
        add the checks of what they turn on. Each command may take up to a
        minute, and finds coreutils, grep, iproute2, systemd and Nix on its
        `PATH`. If one keeps failing for `retrySeconds`,
        `post-switch-checks.service` fails, and `my.alerts.healthchecksIo`
        reports it; with `my.autoRollback`, the machine also goes back to the
        system before. A check that already fails before the switch, twice 15
        seconds apart, does not count.
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
        giving up. The default leaves time for a slow network to come up.
      '';
    };

    run = lib.mkOption {
      type = lib.types.path;
      internal = true;
      readOnly = true;
      default = lib.getExe checks;
      description = ''
        For other modules: `run sample <file>` lists in the file the checks
        that fail already, and `run healthy <file>` fails, printing why, if
        any other check keeps failing.
      '';
    };

    remember = lib.mkOption {
      type = lib.types.str;
      internal = true;
      default = "${lib.getExe checks} sample ${failingBefore}";
      description = "For other modules: the command to run before a switch or an upgrade.";
    };

    verify = lib.mkOption {
      type = lib.types.str;
      internal = true;
      default = "${lib.getExe checks} healthy ${failingBefore}";
      description = ''
        For other modules: the command that judges the system after a switch
        or an upgrade, and fails if it is bad.
      '';
    };

    verifyTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      internal = true;
      readOnly = true;
      # Besides the checks: the switch they wait for, or a rollback.
      default = cfg.settleSeconds + cfg.retrySeconds + 1800;
      description = "For other modules: how long `verify` may take.";
    };
  };

  config = lib.mkIf (cfg.checks != { }) {
    system.preSwitchChecks.post-switch-checks = ''${lib.getExe onSwitch} before "$2"'';
  };
}
