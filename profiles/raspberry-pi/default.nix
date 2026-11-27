# A headless Raspberry Pi booting NixOS from its SD card, any model.
{
  lib,
  modulesPath,
  ...
}:
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
    };

    # Room for the vendor device trees and overlays; the default is 30 MiB.
    sdImage.firmwareSize = 256;

    documentation = {
      nixos.enable = false;
      doc.enable = false;
    };

    # The image asks for drivers of every ARM board; the Pi kernel has few of them.
    hardware.enableAllHardware = lib.mkForce false;

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
