# my.nix.cacheProxy: nix substitutes through ncro, trusting the upstream's key.
{ self, pkgs, ... }:
let
  # A throwaway signing key pair for the upstream cache.
  secretKey = pkgs.writeText "test-upstream.sec" "test-upstream-1:yQB3LYqlTTonzSOZZUfUwpP/hKlCPWjFCrMPO3ZrWzsydqGiZPfbV++a9nJubENZAbufG9LbCjS6o3oyBOgwKg==";
  publicKey = "test-upstream-1:MnahomT321fvmvZybmxDWQG7nxvS2wo0uqN6MgToMCo=";

  payload = pkgs.runCommandLocal "cache-proxy-payload" { } ''
    mkdir $out
    echo "through the proxy" > $out/data
  '';
in
{
  name = "cache-proxy";

  nodes = {
    # A static binary cache holding the signed payload.
    upstream =
      { config, ... }:
      {
        system.extraDependencies = [ payload ];
        nix.settings.experimental-features = [ "nix-command" ];
        networking.firewall.allowedTCPPorts = [ 80 ];

        systemd.services.fill-cache = {
          wantedBy = [ "multi-user.target" ];
          before = [ "nginx.service" ];
          path = [ config.nix.package ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            nix copy --to 'file:///srv/cache?secret-key=${secretKey}' ${payload}
          '';
        };

        services.nginx = {
          enable = true;
          virtualHosts.upstream.root = "/srv/cache";
        };
      };

    machine = {
      imports = [ self.nixosModules.nix-cache-proxy ];

      my.nix.cacheProxy = {
        enable = true;
        upstreams = [
          {
            url = "http://upstream";
            priority = 10;
            public_key = publicKey;
          }
        ];
      };
    };
  };

  testScript = ''
    start_all()
    upstream.wait_for_unit("nginx.service")
    upstream.wait_for_open_port(80)
    machine.wait_for_unit("ncro.service")
    machine.wait_for_open_port(4200)

    with subtest("the proxy is the first substituter, with cache.nixos.org behind it"):
        substituters = machine.succeed("nix config show substituters").split()
        assert substituters[0].startswith("http://localhost:4200"), substituters
        assert "https://cache.nixos.org/" in substituters, substituters

    with subtest("the upstream's key is trusted"):
        assert "${publicKey}" in machine.succeed("nix config show trusted-public-keys")

    with subtest("a path is substituted through the proxy"):
        # The store is shared with the host, so the files are there, but the
        # path is not valid in this machine's database.
        machine.fail("nix path-info ${payload}")
        machine.succeed("nix-store --realise ${payload}")
        machine.succeed("nix path-info ${payload}")
        assert machine.succeed("cat ${payload}/data").strip() == "through the proxy"
        upstream.succeed("grep -q 'GET /nar/' /var/log/nginx/access.log")
  '';
}
