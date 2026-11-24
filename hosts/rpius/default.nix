# A Raspberry Pi 4 in the US: that side's VPN server.
{ inputs, lib, ... }:
{
  imports = [
    inputs.self.nixosModules.default
    inputs.self.nixosModules.raspberry-pi-4
  ];

  networking.hostName = "rpius";

  users.users.damien = {
    isNormalUser = true;
    uid = 1000;
    description = "Damien Nguyen";
    openssh.authorizedKeys.keys = lib.attrValues (import ../../home/damien/ssh-keys.nix) ++ [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEFQdTTDWuE3Kdvky3k2jtl9pa5a5+yV4keJNpT2Fyy"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBA+nIIpFTOVL+ew5gHRNZe5YJzapuKgQUfGqMnHE00n23FEqduqNi5DDhkOmzbYmijtOQF8wJiWPv8HPsKvALG8= termius"
    ];
  };
  home-manager.users.damien = ../../home/damien/minimal.nix;

  my = {
    locale = {
      timeZone = "America/New_York";
      default = "en_US.UTF-8";
    };

    vpnServer.enable = true;

    nix.nixbuild = {
      enable = true;
      systems = [ "aarch64-linux" ];
      extraFeatures = [
        "kvm"
        "nixos-test"
      ];
    };

    hardened = {
      sshUsers = [ "damien" ];
      neverBan = [ "192.168.1.*" ];
    };

    # Early morning there, noon in Zurich.
    autoUpgrade = {
      dates = "06:00";
      rebootWindow = {
        lower = "05:30";
        upper = "08:00";
      };
    };

    # As PiVPN had it. Clients are managed with `nix run .#wireguard-rpius`.
    wireguard = {
      port = 1194;
      subnet = "10.56.236.0/24";
      subnet6 = "fdab:5402:659f::/64";
      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      inherit (lib.importJSON ./wireguard.json) peers;
    };
  };

  system.stateVersion = "26.11";
}
