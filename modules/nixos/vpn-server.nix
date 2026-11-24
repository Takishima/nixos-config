{
  config,
  lib,
  pkgs,
  ...
}:
let
  # `owner/name`, without the branch or parameters a flake reference may add.
  githubRepository = builtins.match "github:([^/?]+/[^/?]+).*" config.my.autoUpgrade.flake;
in
{
  imports = [
    ./alerts/healthchecks-io.nix
    ./auto-upgrade.nix
    ./duckdns.nix
    ./hardened.nix
    ./ssh-server.nix
    ./wireguard.nix
  ];

  options.my.vpnServer.enable = lib.mkEnableOption ''
    a VPN server reachable from the internet. Turns on `my.wireguard`,
    `my.sshServer`, `my.hardened`, `my.duckdns`, `my.autoUpgrade` and
    `my.alerts.healthchecksIo`. The host sets who logs in, its home network,
    and the VPN's port, subnet and clients'';

  config = lib.mkIf config.my.vpnServer.enable {
    my = {
      sshServer.enable = true;
      hardened.enable = true;
      wireguard.enable = true;
      duckdns.enable = lib.mkDefault true;
      alerts.healthchecksIo.enable = lib.mkDefault true;
      autoUpgrade = {
        enable = lib.mkDefault true;
        # Roll back unless the machine can still be logged into and can
        # still fetch the next upgrade. Anything else can be fixed by one.
        checks = {
          sshd = "systemctl is-active --quiet sshd.service";
          upgrade-timer = "systemctl is-active --quiet nixos-upgrade.timer";
          route = "ip route get 1.1.1.1";
        }
        // lib.optionalAttrs (githubRepository != null) {
          repository = "${lib.getExe pkgs.curl} -fsS --max-time 30 -o /dev/null https://github.com/${lib.head githubRepository}";
        };
      };
    };
  };
}
