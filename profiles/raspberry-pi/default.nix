# A headless Raspberry Pi booting NixOS from its SD card, any model.
{
  config,
  lib,
  modulesPath,
  ...
}:
let
  uBoot = !config.my.trialBoot.enable;
in
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image.nix")
    ./argon-one.nix
    ./trial-boot.nix
  ];

  config = {
    nixpkgs.hostPlatform = "aarch64-linux";

    boot = {
      kernelParams = [
        "console=ttyS0,115200n8"
        "console=tty0"
        # Covers early boot, before the watchdog below is running.
        "panic=10"
      ];
      # The Pi takes its address on Ethernet: the radio's driver stays out.
      blacklistedKernelModules = [ "brcmfmac" ];
      loader.timeout = 1;
    };

    sdImage = {
      # Room for the vendor device trees and overlays; the default is 30 MiB.
      firmwareSize = 256;
      populateRootCommands = lib.mkIf uBoot ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
      '';
    };

    documentation = {
      nixos.enable = false;
      doc.enable = false;
    };

    hardware = {
      # The image asks for drivers of every ARM board; the Pi kernel has few of them.
      enableAllHardware = lib.mkForce false;
      raspberry-pi.firmware = {
        # Keep /boot/firmware in step with the system on every switch.
        enable = uBoot;
        uboot.enable = uBoot;
      };
    };

    fileSystems = {
      "/".options = [ "noatime" ];
      # The image leaves it unmounted; mount it when something reads it.
      "/boot/firmware".options = lib.mkForce [
        "noatime"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };

    zramSwap.enable = true;

    # The board's watchdog resets a Pi that hangs, also during a reboot.
    systemd.settings.Manager = {
      RuntimeWatchdogSec = "30s";
      RebootWatchdogSec = "10min";
    };
    # Nobody is at the console: keep booting, so sshd and the upgrades start.
    systemd.enableEmergencyMode = false;

    services = {
      journald.settings.Journal.SystemMaxUse = "100M";
      fstrim.enable = true;
    };

    nix.settings = {
      max-substitution-jobs = 8;
      # A full card would block upgrades.
      min-free = 1024 * 1024 * 1024;
      max-free = 3 * 1024 * 1024 * 1024;
      # CI puts the Pis' kernel in the first, and takes some paths from the second.
      substituters = [
        "https://dn-personal.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "dn-personal.cachix.org-1:8pB//y1vrWsFfDo9FebVmnMU3mF9t4bDDxaeQPN88RE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
