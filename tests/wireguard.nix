# my.wireguard and wireguard-<host>, with nixpkgs' WireGuard test keys.
{
  self,
  sshKeys,
  lib,
  pkgs,
  ...
}:
let
  keys = import "${pkgs.path}/nixos/tests/wireguard/snakeoil-keys.nix";
  phoneKey = lib.trim keys.peer1.publicKey;

  admin = pkgs.callPackage ../pkgs/wireguard-admin.nix {
    host = "testpi";
    port = 51820;
    subnet = "10.6.0.0/24";
    subnet6 = "fd00:6::/64";
    dns = [ "10.6.0.1" ];
    allowedIPs = [ "10.6.0.0/24" ];
  };

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
    server = {
      imports = [ self.nixosModules.wireguard ];

      # As tight as a host can ask for.
      networking.firewall.checkReversePath = "strict";

      # The second network stands in for the server's home network.
      virtualisation.vlans = [
        1
        2
      ];

      environment.systemPackages = [
        admin
        pkgs.jq
      ];

      my = {
        secrets = {
          file = ./fixtures/secrets.yaml;
          sshKeyPath = "${sshKeys.snakeOilEd25519PrivateKey}";
        };
        wireguard = {
          enable = true;
          subnet = "10.6.0.0/24";
          subnet6 = "fd00:6::/64";
          inherit (imported) peers;
        };
      };
    };

    client =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.wireguard-tools ];
      };

    # A second client, which the test adds to the running server.
    tablet =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.wireguard-tools ];
      };

    home.virtualisation.vlans = [ 2 ];
  };

  testScript =
    { nodes, ... }:
    let
      homeAddress = nodes.home.networking.primaryIPAddress;
      serverAtHome = (lib.head nodes.server.networking.interfaces.eth2.ipv4.addresses).address;
    in
    ''
      start_all()
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

      with subtest("a client reaches the home network, behind the server's address"):
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
              " endpoint server:51820 allowed-ips 10.6.0.0/24",
              "ip address add 10.6.0.9/24 dev wg0",
              "ip link set wg0 up",
          )
          tablet.wait_until_succeeds("ping -c 1 10.6.0.1")
          tablet.fail("ping -c 1 -W 2 10.6.0.2")
          client.fail("ping -c 1 -W 2 10.6.0.9")

      with subtest("wireguard-testpi imports an old server as the module has it"):
          server.succeed("mkdir -p /root/repo/hosts/testpi /root/repo/secrets")
          secrets = server.succeed("cd /root/repo && wireguard-testpi import ${oldServer}")
          server.succeed(
              "jq -S . ${pkgs.writeText "imported.json" (builtins.toJSON imported)} | cmp - /root/repo/hosts/testpi/wireguard.json"
          )
          expected = (
              "wireguard:\n"
              '    private_key: "${keys.peer0.privateKey}"\n'
              "    psk:\n"
              '        phone: "${keys.presharedKey}"\n'
          )
          assert secrets == expected, secrets
          server.fail("cd /root/repo && wireguard-testpi import ${oldServer}")

      with subtest("from a tar of /etc/wireguard too"):
          server.succeed(
              "mkdir -p /root/other/hosts/testpi /tmp/wireguard && cp ${oldServer} /tmp/wireguard/wg0.conf",
              # As `tar czf wireguard.tgz /etc/wireguard` stores it, under a directory.
              "tar czf /tmp/wireguard.tgz -C / tmp/wireguard",
              "cd /root/other && wireguard-testpi import /tmp/wireguard.tgz",
              "cmp /root/other/hosts/testpi/wireguard.json /root/repo/hosts/testpi/wireguard.json",
          )

      with subtest("a new client gets the next free address and a configuration"):
          secrets = server.succeed(
              "cd /root/repo && wireguard-testpi add tablet --endpoint vpn.example.org -o /root/tablet.conf"
          )
          assert "        tablet: " in secrets, secrets
          server.succeed(
              "test \"$(jq -r .peers.tablet.address /root/repo/hosts/testpi/wireguard.json)\" = 10.6.0.3",
              "grep -Fx 'Address = 10.6.0.3/24, fd00:6::3/64' /root/tablet.conf",
              "grep -Fx 'PublicKey = ${keys.peer0.publicKey}' /root/tablet.conf",
              "grep -Fx 'Endpoint = vpn.example.org:51820' /root/tablet.conf",
              "grep -Fx 'AllowedIPs = 10.6.0.0/24' /root/tablet.conf",
              "grep -Fx 'DNS = 10.6.0.1' /root/tablet.conf",
              "test \"$(stat -c %a /root/tablet.conf)\" = 600",
              "test \"$(sed -n 's/^PrivateKey = //p' /root/tablet.conf | wg pubkey)\""
              " = \"$(jq -r .peers.tablet.publicKey /root/repo/hosts/testpi/wireguard.json)\"",
          )
          server.fail("cd /root/repo && wireguard-testpi add tablet --endpoint vpn.example.org")

      with subtest("a client that made its own key keeps it"):
          server.succeed(
              "cd /root/repo && wireguard-testpi add laptop --endpoint vpn.example.org"
              " --public-key IujkG119YPr2cVQzJkSLYCdjpHIDjvr/qH1w1tdKswY= -o /root/laptop.conf",
              "grep -F \"PrivateKey = <the client's private key>\" /root/laptop.conf",
              "test \"$(jq -r .peers.laptop.address /root/repo/hosts/testpi/wireguard.json)\" = 10.6.0.4",
          )

      with subtest("the endpoint defaults to the one in the sops file"):
          server.succeed(
              "cp ${./fixtures/secrets.yaml} /root/repo/secrets/testpi.yaml",
              "cd /root/repo && SOPS_AGE_KEY=$(ssh-to-age -private-key -i ${sshKeys.snakeOilEd25519PrivateKey})"
              " wireguard-testpi add watch -o /root/watch.conf",
              "grep -Fx 'Endpoint = vpn.example.org:51820' /root/watch.conf",
          )
          server.fail("cd /root/repo && wireguard-testpi add nokey")

      with subtest("a client is not kept when its secret cannot be written"):
          server.fail("cd /root/repo && wireguard-testpi --sops add nokey --endpoint vpn.example.org")
          server.succeed("test \"$(jq '.peers | has(\"nokey\")' /root/repo/hosts/testpi/wireguard.json)\" = false")

      with subtest("a removed client is gone, a new server starts empty"):
          server.succeed(
              "cd /root/repo && wireguard-testpi remove tablet",
              "test \"$(jq '.peers | has(\"tablet\")' /root/repo/hosts/testpi/wireguard.json)\" = false",
              "cd /root/repo && wireguard-testpi list | grep -q phone",
              "mkdir -p /root/new/hosts/testpi && cd /root/new && wireguard-testpi init | grep -q private_key",
              "test \"$(jq -r '.peers | length' /root/new/hosts/testpi/wireguard.json)\" = 0",
              "jq -e '.publicKey | length == 44' /root/new/hosts/testpi/wireguard.json",
          )
          server.fail("cd /root/new && wireguard-testpi init")
    '';
}
