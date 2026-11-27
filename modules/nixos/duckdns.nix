# Keeps DuckDNS names pointing at this machine's public address.
{ config, lib, ... }:
let
  secrets = {
    token = "duckdns/token";
    domains = "duckdns/domains";
  };
  sandbox = import ../../lib/service-sandbox.nix;
  missing = lib.filter (secret: !config.my.secrets.has secret) (lib.attrValues secrets);
in
{
  imports = [
    ./post-switch.nix
    ./secrets.nix
  ];

  options.my.duckdns.enable = lib.mkEnableOption ''
    updating DuckDNS every five minutes. The sops file holds the account's
    `duckdns/token`, and `duckdns/domains`: the names without `.duckdns.org`,
    one per line. An update that keeps failing fails
    `my.postSwitch.checks`'';

  config = lib.mkIf config.my.duckdns.enable (
    lib.mkMerge [
      (lib.mkIf (missing != [ ]) {
        warnings = [
          "my.duckdns: the sops file lacks ${lib.concatStringsSep " and " missing}, so nothing is updated."
        ];
      })

      (lib.mkIf (missing == [ ]) {
        sops.secrets = lib.genAttrs (lib.attrValues secrets) (_: { });

        services.duckdns = {
          enable = true;
          tokenFile = config.sops.secrets.${secrets.token}.path;
          domainsFile = config.sops.secrets.${secrets.domains}.path;
        };

        my.postSwitch.checks.duckdns = "! systemctl is-failed --quiet duckdns.service";

        # The first run is at boot: wait for an address and DNS.
        systemd.services.duckdns = {
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = sandbox.internetClient;
        };
      })
    ]
  );
}
