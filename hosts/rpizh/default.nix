# A Raspberry Pi 4 in an Argon One case, at home: the VPN's server.
{ inputs, lib, ... }:
{
  imports = [
    inputs.self.nixosModules.default
    inputs.self.nixosModules.raspberry-pi-4
  ];

  networking.hostName = "rpizh";

  users.users.damien = {
    isNormalUser = true;
    uid = 1000;
    description = "Damien Nguyen";
    openssh.authorizedKeys.keys = lib.attrValues (import ../../home/damien/ssh-keys.nix) ++ [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEFQdTTDWuE3Kdvky3k2jtl9pa5a5+yV4keJNpT2Fyy"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMigf+UswNmE2L46CerU9f4ZXHeQnXTMFc9GgBnPzXYyXC5y524zrul6QsZ3cgw4i3l7T7B52pw/E95ih/taoU0= termius"
    ];
  };
  home-manager.users.damien = ../../home/damien/minimal.nix;

  my = {
    locale = {
      timeZone = "Europe/Zurich";
      default = "en_GB.UTF-8";
      formats = "de_CH.UTF-8";
      consoleKeyMap = "sg";
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
      neverBan = [ "10.*" ];
    };

    argonOne.enable = true;

    # Midnight on the US east coast, where the VPN is used until the evening.
    autoUpgrade = {
      dates = "06:00";
      rebootWindow = {
        lower = "05:30";
        upper = "08:00";
      };
    };

    # Clients are managed with `nix run .#wireguard-rpizh`.
    wireguard = {
      port = 1194;
      subnet = "10.117.17.0/24";
      inherit (lib.importJSON ./wireguard.json) peers;
    };
  };

  system.stateVersion = "26.11";
}
