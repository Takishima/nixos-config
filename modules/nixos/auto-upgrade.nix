# Switches to the flake's current system on a timer, and has my.postSwitch judge it.
{
  config,
  lib,
  ...
}:
let
  cfg = config.my.autoUpgrade;
  inherit (config.my) postSwitch;
in
{
  imports = [
    ./alerts/healthchecks-io.nix
    ./post-switch.nix
  ];

  options.my.autoUpgrade = {
    enable = lib.mkEnableOption ''
      switching to the flake's current system on a timer. An upgrade that
      fails `my.postSwitch.checks` fails, and with `my.autoRollback` is
      undone'';

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
    my.alerts.healthchecksIo = {
      units = [ "nixos-upgrade" ];
      heartbeat = [ "nixos-upgrade" ];
    };

    system.autoUpgrade = {
      enable = true;
      flake = "${cfg.flake}#${config.networking.hostName}";
      inherit (cfg) dates allowReboot rebootWindow;
      randomizedDelaySec = "30min";
    };

    systemd.services.nixos-upgrade = lib.mkIf (postSwitch.checks != { }) {
      serviceConfig = {
        # A run that hangs would block every later one, and report nothing.
        TimeoutStartSec = "12h";
        ExecStartPre = postSwitch.remember;
        ExecStopPost = postSwitch.verify;
        TimeoutStopSec = postSwitch.verifyTimeoutSeconds;
      };
    };
  };
}
