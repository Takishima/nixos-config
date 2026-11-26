# Has the Pi's firmware start NixOS itself, a new kernel once as a trial.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (config.hardware.raspberry-pi) configtxt firmware;
  trialBoot = lib.getExe (
    pkgs.callPackage ../../pkgs/trial-boot.nix {
      configTxt = configtxt.file;
      firmware = firmware.package;
      partition = firmware.path;
      vcmailbox = lib.getExe' pkgs.libraspberrypi "vcmailbox";
    }
  );
  judged = options.my ? autoRollback && config.my.autoRollback.enable;
in
{
  options.my.trialBoot.enable = lib.mkEnableOption ''
    starting NixOS from the Raspberry Pi's firmware, without U-Boot. A system
    with another kernel, initrd, device trees or `config.txt` boots once as a
    trial, at the next reboot. Once it has booted, and with `my.autoRollback`
    passed its checks, it is what the Pi boots. Until then a reset, a power
    cut or a second reboot starts the system before. The firmware starts
    the watchdog with the kernel, so a kernel that hangs is reset: that
    needs a boot loader in the EEPROM from July 2025 or later. A switch
    does not update the GPU's boot code, `start4.elf` and `fixup4.dat`'';

  config = lib.mkIf config.my.trialBoot.enable {
    boot.loader.generic-extlinux-compatible.enable = false;
    # The firmware puts cgroup_disable=memory first on the command line.
    boot.kernelParams = [ "cgroup_enable=memory" ];
    system.build.installBootLoader = "${trialBoot} install";
    system.boot.loader.id = "raspberry-pi-trial-boot";

    hardware.raspberry-pi.configtxt.settings.all = {
      arm_64bit = true;
      # Seconds systemd has to take the watchdog over, the first boot's resize included.
      kernel_watchdog_timeout = 300;
    };

    sdImage = {
      populateRootCommands = "";
      # Above the mkForce of nixos-hardware, which writes a config.txt for U-Boot.
      populateFirmwareCommands = lib.mkOverride 40 ''
        ${trialBoot} image ./firmware ${config.system.build.toplevel}
      '';
    };

    systemd.services.trial-boot-confirm = {
      description = "Keep the system a trial boot started";
      wantedBy = [ "multi-user.target" ];
      requires = lib.optional judged "nixos-upgrade-confirm.service";
      after = lib.optional judged "nixos-upgrade-confirm.service";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${trialBoot} confirm";
      };
    };
  };
}
