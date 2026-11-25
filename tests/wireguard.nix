# my.wireguard and wireguard-<host>, with nixpkgs' WireGuard test keys.
{
  self,
  fixtureSecrets,
  sshKeys,
  lib,
  pkgs,
  ...
}:
let
  keys = import "${pkgs.path}/nixos/tests/wireguard/snakeoil-keys.nix";
  phoneKey = lib.trim keys.peer1.publicKey;

  # As PiVPN writes it.
  oldServer = pkgs.writeText "wg0.conf" ''
    [Interface]
    PrivateKey = ${keys.peer0.privateKey}
    Address = 10.6.0.1/24
    MTU = 1420
    ListenPort = 51820
    ### begin phone ###
    [Peer]
    PublicKey = ${phoneKey}
    PresharedKey = ${keys.presharedKey}
    AllowedIPs = 10.6.0.2/32
    ### end phone ###
    #[disabled] ### begin old laptop ###
    #[disabled] [Peer]
    #[disabled] PublicKey = xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=
    #[disabled] AllowedIPs = 10.6.0.5/32
    #[disabled] ### end old laptop ###
  '';

  imported = {
    publicKey = keys.peer0.publicKey;
    peers = {
      phone = {
        publicKey = phoneKey;
        address = "10.6.0.2";
      };
      old_laptop = {
        publicKey = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
        address = "10.6.0.5";
        enable = false;
      };
    };
  };

  withoutPresharedKey = pkgs.nixos {
    imports = [ self.nixosModules.wireguard ];
    my = {
      secrets = fixtureSecrets;
      wireguard = {
        enable = true;
        subnet = "10.6.0.0/24";
        peers.tablet = {
          publicKey = phoneKey;
          address = "10.6.0.3";
        };
      };
    };
  };

  phoneConf = pkgs.writeText "phone.conf" ''
    [Interface]
    PrivateKey = ${keys.peer1.privateKey}
    Address = 10.6.0.2/24, fd00:6::2/64

    [Peer]
    PublicKey = ${keys.peer0.publicKey}
    PresharedKey = ${keys.presharedKey}
    Endpoint = server:51820
    AllowedIPs = 10.6.0.0/24, fd00:6::/64, 192.168.2.0/24
  '';
in
{
  name = "wireguard";

  nodes = {
    server =
      { config, ... }:
      {
        imports = [ self.nixosModules.wireguard ];

        # As tight as a host can ask for.
        networking.firewall.checkReversePath = "strict";

        # The second network stands in for the server's home network.
        virtualisation.vlans = [
          1
          2
        ];

        environment.systemPackages = [
          (pkgs.callPackage ../pkgs/wireguard-admin.nix {
            host = "testpi";
            server = config.my.wireguard;
          })
          pkgs.jq
          pkgs.sops
        ];

        my = {
          secrets = fixtureSecrets;
          wireguard = {
            enable = true;
            subnet = "10.6.0.0/24";
            subnet6 = "fd00:6::/64";
            dns = [ "10.6.0.1" ];
            allowedIPs = [ "10.6.0.0/24" ];
            peers = lib.mkMerge [
              imported.peers
              { phone.localNetwork = true; }
            ];
          };
        };
      };

    client.environment.systemPackages = [ pkgs.wireguard-tools ];
    # A second client, which the test adds to the running server.
    tablet.environment.systemPackages = [ pkgs.wireguard-tools ];

    home.virtualisation.vlans = [ 2 ];

    # As a freshly installed host: no sops file yet. Never started.
    fresh = {
      imports = [ self.nixosModules.wireguard ];
      my = {
        secrets.file = null;
        wireguard = {
          enable = true;
          subnet = "10.6.0.0/24";
        };
      };
    };
  };

  testScript =
    { nodes, ... }:
    let
      homeAddress = nodes.home.networking.primaryIPAddress;
      internetAddress = "203.0.113.1";
      serverAtHome = (lib.head nodes.server.networking.interfaces.eth2.ipv4.addresses).address;
    in
    assert lib.assertMsg (
      nodes.fresh.networking.firewall.allowedUDPPorts == [ ]
      && !nodes.fresh.networking.firewall.filterForward
      && !nodes.fresh.networking.nat.enable
      && nodes.fresh.networking.wireguard.interfaces == { }
      && !(nodes.fresh.my.autoUpgrade.checks ? wireguard)
      && lib.any (lib.hasInfix "my.wireguard") nodes.fresh.warnings
    ) "without its sops key, my.wireguard must open nothing and say so";
    assert lib.assertMsg (lib.any
      ({ assertion, message }: !assertion && lib.hasInfix "wireguard/psk/<name>" message)
      withoutPresharedKey.config.assertions
    ) "my.wireguard must refuse a client without a preshared key";
    ''
      import json

      server.start()
      client.start()
      tablet.start()
      home.start()
      server.wait_for_unit("wireguard-wg0.target")

      with subtest("the server has the declared clients, but not the disabled one"):
          peers = server.succeed("wg show wg0 allowed-ips")
          assert "${phoneKey}\t10.6.0.2/32 fd00:6::2/128" in peers, peers
          assert "10.6.0.5" not in peers, peers
          assert server.succeed("wg show wg0 public-key").strip() == "${keys.peer0.publicKey}"

      with subtest("wg-peers names the clients, for root only"):
          named = server.succeed("wg-peers")
          assert "peer: phone (${phoneKey})" in named, named
          assert "old_laptop" not in named, named
          status, out = server.execute("su nobody -s /bin/sh -c wg-peers 2>&1")
          assert status != 0, out

      with subtest("a client connects with its key and preshared key"):
          client.succeed("install -m 600 ${phoneConf} /root/phone.conf", "wg-quick up /root/phone.conf")
          client.wait_until_succeeds("ping -c 1 10.6.0.1")
          client.wait_until_succeeds("ping -c 1 fd00:6::1")

      with subtest("a client with localNetwork reaches the home network, behind the server's address"):
          # `home` has no route to the VPN: an answer shows the NAT.
          client.succeed("ping -c 1 -W 5 ${homeAddress}")

      with subtest("the home network does not reach a client"):
          home.succeed("ip route add 10.6.0.0/24 via ${serverAtHome}")
          home.fail("ping -c 1 -W 2 10.6.0.2")

      with subtest("clients do not reach one another"):
          tablet.succeed("umask 077 && wg genkey > /root/key")
          server.succeed(f"wg set wg0 peer {tablet.succeed('wg pubkey < /root/key').strip()} allowed-ips 10.6.0.9/32")
          tablet.succeed(
              "ip link add wg0 type wireguard",
              "wg set wg0 private-key /root/key peer ${keys.peer0.publicKey}"
              " endpoint server:51820 allowed-ips 10.6.0.0/24,192.168.2.0/24,${internetAddress}/32",
              "ip address add 10.6.0.9/24 dev wg0",
              "ip link set wg0 up",
              "ip route add 192.168.2.0/24 dev wg0",
              "ip route add ${internetAddress} dev wg0",
          )
          tablet.wait_until_succeeds("ping -c 1 10.6.0.1")
          tablet.fail("ping -c 1 -W 2 10.6.0.2")
          client.fail("ping -c 1 -W 2 10.6.0.9")

      with subtest("a client without localNetwork reaches the internet, not the home network"):
          home.succeed("ip address add ${internetAddress}/32 dev lo")
          server.succeed("ip route add ${internetAddress} via ${homeAddress}")
          tablet.succeed("ping -c 1 -W 5 ${internetAddress}")
          tablet.fail("ping -c 1 -W 2 ${homeAddress}")

      key = "SOPS_AGE_KEY=$(ssh-to-age -private-key -i ${sshKeys.snakeOilEd25519PrivateKey})"

      def checkout(name):
          """Makes a checkout holding only the fixture's sops file: the command to run in it."""
          server.succeed(
              f"mkdir -p /root/{name}/hosts/testpi /root/{name}/secrets",
              f"cp ${./fixtures/secrets.yaml} /root/{name}/secrets/testpi.yaml",
          )
          return f"cd /root/{name} && {key} wireguard-testpi"

      def sops(name, action, path, file="secrets/testpi.yaml"):
          index = "".join(f'["{part}"]' for part in path.split("/"))
          first, second = (file, f"'{index}'") if action == "unset" else (f"'{index}'", file)
          return f"cd /root/{name} && {key} sops {action} {first} {second}"

      def secret(name, path):
          return server.succeed(sops(name, "decrypt --extract", path)).strip()

      def state(name, query):
          return server.succeed(f"jq -c '{query}' /root/{name}/hosts/testpi/wireguard.json").strip()

      with subtest("wireguard-testpi imports an old server as the module has it"):
          admin = checkout("repo")
          for path in ["wireguard/private_key", "wireguard/psk"]:
              server.succeed(sops("repo", "unset", path))
          server.succeed(
              f"{admin} import ${oldServer}",
              "jq -S . ${pkgs.writeText "imported.json" (builtins.toJSON imported)} | cmp - /root/repo/hosts/testpi/wireguard.json",
          )
          private = secret("repo", "wireguard/private_key")
          assert private == "${keys.peer0.privateKey}", private
          psk = secret("repo", "wireguard/psk/phone")
          assert psk == "${keys.presharedKey}", psk
          server.fail(f"{admin} import ${oldServer}")

      with subtest("from a tar of /etc/wireguard too"):
          other = checkout("other")
          server.succeed(
              "mkdir -p /tmp/wireguard && cp ${oldServer} /tmp/wireguard/wg0.conf",
              # As `tar czf wireguard.tgz /etc/wireguard` stores it, under a directory.
              "tar czf /tmp/wireguard.tgz -C / tmp/wireguard",
              f"{other} import /tmp/wireguard.tgz",
              "cmp /root/other/hosts/testpi/wireguard.json /root/repo/hosts/testpi/wireguard.json",
          )

      with subtest("a new client gets the next free address, a preshared key and a configuration"):
          server.succeed(f"{admin} add tablet --endpoint vpn.example.org -o /root/tablet.conf")
          psk = secret("repo", "wireguard/psk/tablet")
          server.succeed(
              "grep -Fx 'Address = 10.6.0.3/24, fd00:6::3/64' /root/tablet.conf",
              "grep -Fx 'PublicKey = ${keys.peer0.publicKey}' /root/tablet.conf",
              f"grep -Fx 'PresharedKey = {psk}' /root/tablet.conf",
              "grep -Fx 'Endpoint = vpn.example.org:51820' /root/tablet.conf",
              "grep -Fx 'AllowedIPs = 10.6.0.0/24' /root/tablet.conf",
              "grep -Fx 'DNS = 10.6.0.1' /root/tablet.conf",
              "test \"$(stat -c %a /root/tablet.conf)\" = 600",
          )
          tablet_json = state("repo", ".peers.tablet")
          public = server.succeed("sed -n 's/^PrivateKey = //p' /root/tablet.conf | wg pubkey").strip()
          assert tablet_json == f'{{"address":"10.6.0.3","publicKey":"{public}"}}', tablet_json
          server.fail(f"{admin} add tablet --endpoint vpn.example.org")

      with subtest("a client that made its own key keeps it"):
          server.succeed(
              f"{admin} add laptop --endpoint vpn.example.org"
              " --public-key IujkG119YPr2cVQzJkSLYCdjpHIDjvr/qH1w1tdKswY= -o /root/laptop.conf",
              "grep -F \"PrivateKey = <the client's private key>\" /root/laptop.conf",
          )
          address = state("repo", ".peers.laptop.address")
          assert address == '"10.6.0.4"', address

      with subtest("the endpoint defaults to the one in the sops file"):
          server.succeed(
              f"{admin} add watch -o /root/watch.conf",
              "grep -Fx 'Endpoint = vpn.example.org:51820' /root/watch.conf",
          )

      with subtest("a client is not kept when its secret cannot be written"):
          status, out = server.execute("cd /root/repo && wireguard-testpi add nokey --endpoint vpn.example.org 2>&1")
          assert status != 0 and "sops cannot decrypt" in out, out
          kept = state("repo", '.peers | has("nokey")')
          assert kept == "false", kept

      with subtest("rotate replaces the server's key and every client's preshared key, and changes no client"):
          clients = state("repo", ".peers")
          old_key = state("repo", ".publicKey")
          server.fail(f"{admin} rotate -o")
          untouched = state("repo", ".publicKey")
          assert untouched == old_key, untouched
          server.succeed(f"{admin} rotate -o /root/rotated.txt")

          new_key = json.loads(state("repo", ".publicKey"))
          assert new_key != json.loads(old_key) and len(new_key) == 44, new_key
          kept = state("repo", ".peers")
          assert kept == clients, kept
          private = secret("repo", "wireguard/private_key")
          from_secret = server.succeed(f"echo '{private}' | wg pubkey").strip()
          assert from_secret == new_key, from_secret

          with_psk = server.succeed(
              sops("repo", "decrypt --output-type json --extract", "wireguard/psk") + " | jq -c keys"
          ).strip()
          names = state("repo", ".peers | keys")
          assert with_psk == names, with_psk
          stored = secret("repo", "wireguard/psk/phone")
          assert stored != "${keys.presharedKey}", stored
          phone = server.succeed("grep -A2 '^phone:$' /root/rotated.txt")
          assert f"PublicKey = {new_key}\nPresharedKey = {stored}" in phone, phone
          mode = server.succeed("stat -c %a /root/rotated.txt").strip()
          assert mode == "600", mode

      with subtest("a disabled client stays in the file, shut out, until it is enabled, without the sops key"):
          without_key = "cd /root/repo && wireguard-testpi"
          server.succeed(f"{without_key} disable tablet", f"{without_key} list | grep -E 'tablet.*disabled'")
          enable = state("repo", ".peers.tablet.enable")
          assert enable == "false", enable
          server.succeed(f"{without_key} enable tablet")
          has_enable = state("repo", '.peers.tablet | has("enable")')
          assert has_enable == "false", has_enable
          server.fail(f"{without_key} disable nobody")

      with subtest("local-network lets a client into the local network, until internet-only"):
          server.succeed(f"{without_key} local-network tablet", f"{without_key} list | grep -E 'tablet.*local network'")
          local = state("repo", ".peers.tablet.localNetwork")
          assert local == "true", local
          server.succeed(f"{without_key} internet-only tablet")
          has_local = state("repo", '.peers.tablet | has("localNetwork")')
          assert has_local == "false", has_local
          server.fail(f"{without_key} local-network nobody")

      with subtest("a removed client is gone, with its preshared key"):
          server.succeed(f"{admin} remove tablet", f"{admin} list | grep -q phone")
          kept = state("repo", '.peers | has("tablet")')
          assert kept == "false", kept
          status, out = server.execute(sops("repo", "decrypt --extract", "wireguard/psk/tablet") + " 2>&1")
          assert status != 0, out

      with subtest("rotate refuses a file that has no server"):
          none = checkout("none")
          status, out = server.execute(f"{none} rotate 2>&1")
          assert status != 0 and "no server yet" in out, out

      with subtest("a new server starts empty, with a key of its own"):
          new = checkout("new")
          server.succeed(f"{new} init")
          count = state("new", ".peers | length")
          assert count == "0", count
          private = secret("new", "wireguard/private_key")
          assert private != "${keys.peer0.privateKey}", private
          public = server.succeed(f"echo '{private}' | wg pubkey").strip()
          stored = json.loads(state("new", ".publicKey"))
          assert stored == public, stored
          server.fail(f"{new} init")
    '';
}
