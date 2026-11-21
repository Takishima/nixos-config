# Raspberry Pi 4 Model B, booting from the SD card. Headless.
{
  inputs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.default
    # The Raspberry Pi kernel, built from source, with the firmware partition
    # and its config.txt (hardware.raspberry-pi.configtxt).
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    # The FIRMWARE and NIXOS_SD partitions, and the image as system.build.sdImage.
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  # The image profile asks for ZFS, one more module to compile for this kernel.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  hardware = {
    # The image asks for drivers of every ARM board; the Pi kernel has few of them.
    enableAllHardware = lib.mkForce false;
    enableRedistributableFirmware = true;
    raspberry-pi.firmware = {
      # Keep /boot/firmware in step with the system on every switch.
      enable = true;
      uboot.enable = true;
    };
  };

  # Room for the vendor device trees and overlays; the default is 30 MiB.
  sdImage.firmwareSize = 256;

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

  networking = {
    hostName = "rpizh";
    networkmanager.enable = true;
  };

  zramSwap.enable = true;
  services.journald.settings.Journal.SystemMaxUse = "100M";

  # my.nix sizes these for a desktop.
  nix.settings = {
    max-substitution-jobs = lib.mkForce 8;
    download-buffer-size = lib.mkForce 67108864;
  };

  my = {
    user = {
      name = "damien";
      fullName = "Damien Nguyen";
      home = ../../home/damien/rpizh.nix;
    };

    # Not there yet: see README.md, "Raspberry Pi".
    secrets.file = ../../secrets/rpizh.yaml;

    locale = {
      timeZone = "Europe/Zurich";
      default = "en_GB.UTF-8";
      formats = "de_CH.UTF-8";
      consoleKeyMap = "sg";
    };

    sshServer = {
      enable = true;
      authorizedKeys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBM5JljjHQs7Ns5py2ZxQ7EdtVdD5Iz5/haaojthURiq4Gr1IYxdujftRrzJelucvYUPC0hzvkmgCfGPrFOwTQYY="
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFR+WJj9Kg744PDXXIrmBFbkv7dbetZJSjBbQc1utF1R"
      ];
    };
  };

  system.stateVersion = "26.11";
}
