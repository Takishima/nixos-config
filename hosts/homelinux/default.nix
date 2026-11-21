{
  inputs,
  pkgs,
  ...
}:
{
  imports = with inputs.nixos-hardware.nixosModules; [
    inputs.self.nixosModules.default
    ./disko.nix
    ./hardware-configuration.nix
    ./wifi.nix
    common-cpu-amd
    common-cpu-amd-pstate
    common-gpu-amd
    common-pc-ssd
  ];

  networking = {
    hostName = "homelinux";
    networkmanager.enable = true;
  };

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 10;
      };
    };
    # ath12k (WCN785x) needs a recent kernel.
    kernelPackages = pkgs.linuxPackages_latest;
    binfmt = {
      emulatedSystems = [ "aarch64-linux" ];
      preferStaticEmulators = true;
    };
  };

  zramSwap.enable = true;

  my = {
    user = {
      name = "damien";
      fullName = "Damien Nguyen";
      home = ../../home/damien/homelinux.nix;
    };

    secrets.file = ../../secrets/homelinux.yaml;

    locale = {
      timeZone = "Europe/Zurich";
      default = "en_GB.UTF-8";
      formats = "de_CH.UTF-8";
      consoleKeyMap = "sg";
      xkb = {
        layout = "ch";
        variant = "fr_mac";
      };
    };

    nix = {
      cacheProxy.enable = true;
      nixbuild.enable = true;
    };

    desktop.niri.enable = true;
    audio.enable = true;
    bluetooth.enable = true;
    printing = {
      enable = true;
      default = "Samsung-M283x";
      printers.Samsung-M283x = {
        description = "Samsung M283x";
        uri = "socket://10.3.3.11:9100";
        model = "pxlmono.ppd";
        options.PageSize = "A4";
      };
    };
    onePassword.enable = true;
    sshServer = {
      enable = true;
      authorizedKeys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBM5JljjHQs7Ns5py2ZxQ7EdtVdD5Iz5/haaojthURiq4Gr1IYxdujftRrzJelucvYUPC0hzvkmgCfGPrFOwTQYY="
      ];
    };
    fonts.packages = with pkgs; [
      eb-garamond
      inconsolata
      font-awesome
    ];
    logitech.enable = true;
    fanControl = {
      enable = true;
      it87 = true;
    };
    smartcard = {
      enable = true;
      yubikey = true;
    };
    virtualisation = {
      docker.enable = true;
      libvirt.enable = true;
    };
  };

  services = {
    tailscale.enable = true;
    fwupd.enable = true;
  };

  programs = {
    firefox.enable = true;
    steam.enable = true;
  };

  # The old Manjaro /home.
  fileSystems."/mnt/manjaro-home" = {
    device = "/dev/disk/by-uuid/c1c51984-89c8-4edf-aff3-84f4caec7c45";
    fsType = "ext4";
    options = [
      "ro"
      "nofail"
      "noauto"
      "x-systemd.automount"
    ];
  };

  system.stateVersion = "26.11";
}
