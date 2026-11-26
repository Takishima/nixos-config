# A Raspberry Pi 4 in an Argon One case, at home: the VPN's server.
{ inputs, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.default
    inputs.self.nixosModules.raspberry-pi-4
    ../../home/damien/server-account.nix
  ];

  networking.hostName = "rpizh";

  my = {
    locale = {
      timeZone = "Europe/Zurich";
      default = "en_GB.UTF-8";
      formats = "de_CH.UTF-8";
      consoleKeyMap = "sg";
    };

    vpnServer.enable = true;

    hardened.neverBan = [ "10.*" ];

    argonOne.enable = true;

    trialBoot.enable = true;

    homebridge = {
      enable = true;
      plugins = [
        pkgs.homebridge-miot
        pkgs.homebridge-synology
      ];
    };

    # PiVPN's port and network, which the clients it set up still use.
    wireguard = {
      port = 1194;
      subnet = "10.117.17.0/24";
    };
  };

  system.stateVersion = "26.11";
}
