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
    ./nix-nixbuild.nix
    ./ssh-server.nix
    ./wireguard.nix
  ];

  options.my.vpnServer.enable = lib.mkEnableOption ''
    a VPN server reachable from the internet. Turns on `my.wireguard`,
    `my.sshServer`, `my.hardened`, `my.duckdns`, `my.autoUpgrade`,
    `my.alerts.healthchecksIo`, and `my.nix.nixbuild` for the server's own
    system. The server upgrades at 06:00 in `my.locale.timeZone`, and
    reboots for a new kernel before 08:00. The host sets who logs in, its
    home network, its time zone, and the VPN's port, subnet and clients'';

  config = lib.mkIf config.my.vpnServer.enable {
    my = {
      sshServer.enable = true;
      hardened.enable = true;
      wireguard.enable = true;
      duckdns.enable = lib.mkDefault true;
      alerts.healthchecksIo.enable = lib.mkDefault true;
      # A small server is slow and has no KVM: it builds elsewhere.
      nix.nixbuild = {
        enable = lib.mkDefault true;
        systems = lib.mkDefault [ pkgs.stdenv.hostPlatform.system ];
        extraFeatures = lib.mkDefault [
          "kvm"
          "nixos-test"
        ];
      };
      autoUpgrade = {
        enable = lib.mkDefault true;
        dates = lib.mkDefault "06:00";
        rebootWindow = lib.mkDefault {
          lower = "05:30";
          upper = "08:00";
        };
        # An upgrade that can still fetch the next one can be fixed by it.
        checks = {
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
