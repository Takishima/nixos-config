{ config, lib, ... }:
{
  imports = [
    ./auto-upgrade.nix
    ./duckdns.nix
    ./hardened.nix
    ./nix.nix
    ./ssh-server.nix
    ./wireguard.nix
  ];

  options.my.vpnServer.enable = lib.mkEnableOption ''
    a VPN server reachable from the internet. Turns on `my.wireguard`,
    `my.sshServer`, `my.hardened`, `my.duckdns` and `my.autoUpgrade`. The
    host sets who logs in, its home network, and the VPN's port, subnet and
    clients'';

  config = lib.mkIf config.my.vpnServer.enable {
    my = {
      sshServer.enable = true;
      hardened.enable = true;
      wireguard.enable = true;
      duckdns.enable = lib.mkDefault true;
      autoUpgrade = {
        enable = lib.mkDefault true;
        # What must still work after an upgrade, or it is undone.
        checks = [
          "systemctl is-active --quiet sshd.service"
          "ip route get 1.1.1.1"
        ]
        ++ lib.optional (config.my.secrets.has "wireguard/private_key") "systemctl is-active --quiet wireguard-wg0.service";
      };
    };
  };
}
