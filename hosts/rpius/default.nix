# A Raspberry Pi 4 in the US: that side's VPN server.
{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.default
    inputs.self.nixosModules.raspberry-pi-4
    ../../home/damien/server-account.nix
  ];

  networking.hostName = "rpius";

  my = {
    locale = {
      timeZone = "America/New_York";
      default = "en_US.UTF-8";
    };

    vpnServer.enable = true;

    hardened.neverBan = [ "192.168.1.*" ];

    # PiVPN's port and network, which the clients it set up still use.
    wireguard = {
      port = 1194;
      subnet = "10.56.236.0/24";
      subnet6 = "fdab:5402:659f::/64";
      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };
  };

  system.stateVersion = "26.11";
}
