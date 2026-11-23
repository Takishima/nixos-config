{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.autoUpgrade;
  previous = "/run/nixos-upgrade-previous";

  remember = pkgs.writeShellScript "nixos-upgrade-remember" ''
    readlink /run/current-system > ${previous}
  '';

  # Runs when the upgrade ends, whether it failed or not.
  verify = pkgs.writeShellScript "nixos-upgrade-verify" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.iproute2
        config.systemd.package
        config.nix.package.out
      ]
    }
    was=$(cat ${previous}) || exit 0
    [ "$(readlink /run/current-system)" != "$was" ] || exit 0

    sleep ${toString cfg.settleSeconds}
    failed=
    ${lib.concatMapStrings (check: ''
      if ! (${check}) > /dev/null; then
        echo "check failed: "${lib.escapeShellArg check}
        failed=1
      fi
    '') cfg.checks}
    [ -n "$failed" ] || exit 0

    echo "the upgraded system fails its checks: going back to $was"
    nix-env --profile /nix/var/nix/profiles/system --set "$was"
    # Without the boot loader if that part fails: the running system matters first.
    "$was/bin/switch-to-configuration" switch || "$was/bin/switch-to-configuration" test
    exit 1
  '';
in
{
  options.my.autoUpgrade = {
    enable = lib.mkEnableOption "switching to the flake's current system on a timer";

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:takishima/nixos-config";
      description = ''
        The flake to follow; the system is its `nixosConfigurations.<hostname>`.
        One anybody can read, as the machine fetches it without credentials.
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
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "systemctl is-active --quiet sshd.service" ];
      description = ''
        Shell commands that must all succeed once an upgrade has switched the
        running system. If one fails, the machine switches back to the system
        it ran before, and tries the upgrade again at the next run. They are
        not run after an upgrade that reboots.
      '';
    };

    settleSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 30;
      description = "How long to wait after the switch before running `checks`.";
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
    system.autoUpgrade = {
      enable = true;
      flake = "${cfg.flake}#${config.networking.hostName}";
      inherit (cfg) dates allowReboot rebootWindow;
      randomizedDelaySec = "30min";
    };

    systemd.services.nixos-upgrade.serviceConfig = lib.mkIf (cfg.checks != [ ]) {
      ExecStartPre = remember;
      ExecStopPost = verify;
      # Going back is another switch.
      TimeoutStopSec = "30min";
    };
  };
}
