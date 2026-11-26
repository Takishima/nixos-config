# my.homebridge beside my.wireguard, as on rpizh: who reaches the bridge and
# its web interface, who administers it, and what the service may do.
{
  self,
  fixtureSecrets,
  lib,
  pkgs,
  ...
}:
let
  keys = import "${pkgs.path}/nixos/tests/wireguard/snakeoil-keys.nix";

  phoneConf = pkgs.writeText "phone.conf" ''
    [Interface]
    PrivateKey = ${keys.peer1.privateKey}
    Address = 10.6.0.2/24

    [Peer]
    PublicKey = ${keys.peer0.publicKey}
    PresharedKey = ${keys.presharedKey}
    Endpoint = server:51820
    AllowedIPs = 10.6.0.0/24
  '';
in
{
  name = "homebridge";

  nodes = {
    server =
      { pkgs, ... }:
      {
        imports = [
          self.nixosModules.homebridge
          self.nixosModules.wireguard
        ];

        environment.systemPackages = [ pkgs.jq ];

        my = {
          secrets = fixtureSecrets;
          homebridge = {
            enable = true;
            plugins = [
              pkgs.homebridge-miot
              pkgs.homebridge-synology
            ];
          };
          wireguard = {
            enable = true;
            subnet = "10.6.0.0/24";
            peers.phone = {
              publicKey = lib.trim keys.peer1.publicKey;
              address = "10.6.0.2";
            };
          };
        };
      };

    client = {
      environment.systemPackages = [ pkgs.wireguard-tools ];
      services.avahi.enable = true;
    };

    # As a freshly installed host: no sops file yet. Never started.
    fresh = {
      imports = [ self.nixosModules.homebridge ];
      my = {
        secrets.file = null;
        homebridge.enable = true;
      };
    };
  };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.server.services.homebridge) settings uiSettings;
      bridge = toString settings.bridge.port;
      ui = toString uiSettings.port;
      childBridge = toString settings.ports.start;
    in
    assert lib.assertMsg (
      lib.any (lib.hasInfix "homebridge/password_hash") nodes.fresh.warnings
      && lib.any (lib.hasInfix "homebridge/pin") nodes.fresh.warnings
      && nodes.fresh.sops.secrets == { }
    ) "without its sops keys, my.homebridge must say what is left open";
    ''
      import json

      server.start()
      client.start()
      server.wait_for_unit("homebridge.service")
      server.wait_for_unit("wireguard-wg0.target")
      server.wait_for_open_port(${ui})
      server.wait_for_open_port(${bridge})

      def main_pid():
          return server.succeed("systemctl show --property=MainPID --value homebridge.service").strip()

      with subtest("the home network reaches the web interface, the bridge and a child bridge"):
          client.succeed("curl -fsS --max-time 10 -o /dev/null http://server:${ui}/")
          client.succeed("nc -z -w 5 server ${bridge}")
          server.succeed("systemd-run --unit=child-bridge nc -lk ${childBridge}")
          server.wait_for_open_port(${childBridge})
          client.succeed("nc -z -w 5 server ${childBridge}")

      with subtest("the home network finds the bridge over mDNS"):
          client.wait_for_unit("avahi-daemon.service")
          client.wait_until_succeeds("avahi-browse --terminate --resolve _hap._tcp | grep -F 'port = [${bridge}]'", timeout=300)

      with subtest("a VPN client reaches the server, but not Homebridge"):
          client.succeed("install -m 600 ${phoneConf} /root/phone.conf", "wg-quick up /root/phone.conf")
          client.wait_until_succeeds("ping -c 1 10.6.0.1")
          status, out = client.execute("curl -sS --max-time 5 -o /dev/null http://10.6.0.1:${ui}/ 2>&1")
          assert status != 0, out
          client.fail("nc -z -w 5 10.6.0.1 ${bridge}")
          client.fail("nc -z -w 5 10.6.0.1 ${childBridge}")

      with subtest("the service runs without privileges, and cannot gain any"):
          process = server.succeed(f"cat /proc/{main_pid()}/status")
          assert "CapEff:\t0000000000000000" in process, process
          assert "NoNewPrivs:\t1" in process, process
          assert "\nUid:\t0" not in process, process

      api = "curl -sS http://localhost:${ui}/api"

      def login(password):
          return f"{api}/auth/login -f --json '{{\"username\": \"admin\", \"password\": \"{password}\"}}'"

      with subtest("the administrator has the password of the sops file, and nobody sets another"):
          token = json.loads(server.succeed(login("open-sesame-bridge")))["access_token"]
          status, out = server.execute(login("admin") + " 2>&1")
          assert status != 0, out
          status, out = server.execute(f"{api}/setup-wizard/get-setup-wizard-token -f 2>&1")
          assert status != 0, out

      with subtest("the bridge pairs with the code of the sops file"):
          server.succeed("grep -F 482-91-537 /var/lib/homebridge/homebridge.log")
          server.fail("grep -F 031-45-154 /var/lib/homebridge/homebridge.log /var/lib/homebridge/config.json")

      with subtest("the web interface offers no terminal"):
          settings = server.succeed(f"{api}/auth/settings -f -H 'Authorization: Bearer {token}'")
          assert json.loads(settings)["env"]["enableTerminalAccess"] is False, settings

      def plugins():
          return server.succeed(f"{api}/plugins -f -H 'Authorization: Bearer {token}'")

      with subtest("Homebridge has the declared plugins"):
          installed = {plugin["name"] for plugin in json.loads(plugins())}
          assert {"homebridge-miot", "homebridge-synology"} <= installed, installed
          server.wait_until_succeeds("grep -F 'Loaded plugin: homebridge-miot@' /var/lib/homebridge/homebridge.log")
          server.wait_until_succeeds("grep -F 'Loaded plugin: homebridge-synology@' /var/lib/homebridge/homebridge.log")

      with subtest("a user or a plugin set in the web interface is gone after a restart"):
          server.succeed(
              "echo '[]' > /var/lib/homebridge/auth.json",
              "cp -rL /var/lib/homebridge/node_modules/homebridge-miot /var/lib/homebridge/node_modules/homebridge-other",
              "systemctl restart homebridge.service",
          )
          server.wait_for_open_port(${ui})
          token = json.loads(server.succeed(login("open-sesame-bridge")))["access_token"]
          server.fail("test -e /var/lib/homebridge/node_modules/homebridge-other")

      with subtest("the web interface restarts the service after a change to its own settings"):
          before = main_pid()
          server.succeed(
              "jq '(.platforms[] | select(.platform == \"config\")).tempUnits = \"f\"'"
              " /var/lib/homebridge/config.json > /tmp/config.json",
              f"{api}/config-editor -f -H 'Authorization: Bearer {token}' --json @/tmp/config.json",
              f"{api}/server/restart -f -X PUT -H 'Authorization: Bearer {token}'",
          )
          server.wait_until_succeeds(f"test $(systemctl show --property=MainPID --value homebridge.service) != {before}")
          server.wait_for_open_port(${ui})
          server.wait_for_open_port(${bridge})

      with subtest("a session does not outlast a restart"):
          status, out = server.execute(f"{api}/plugins -f -H 'Authorization: Bearer {token}' 2>&1")
          assert status != 0, out

      with subtest("Homebridge started without an error"):
          status, out = server.execute("grep -E 'ERROR|Error' /var/lib/homebridge/homebridge.log")
          assert status != 0, out
    '';
}
