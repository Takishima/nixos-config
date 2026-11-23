# my.hardened: only the listed user logs in over
# SSH, root has the password of the sops file and there is no sudo, and
# fail2ban bans a stranger who keeps failing but never the home network.
{
  self,
  sshKeys,
  lib,
  pkgs,
  ...
}:
let
  # checkPassword <password> <hash>: whether the hash is of the password.
  checkPassword = pkgs.writeScript "check-password" ''
    #!${lib.getExe pkgs.perl}
    exit(crypt($ARGV[0], $ARGV[1]) eq $ARGV[1] ? 0 : 1);
  '';
  # Over IPv4, so that one address fails and is banned.
  ssh = "ssh -n -4 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -i /root/key";
in
{
  name = "hardened";

  nodes = {
    server = {
      imports = [ self.nixosModules.default ];

      users.users = {
        alice = {
          isNormalUser = true;
          openssh.authorizedKeys.keys = [ sshKeys.snakeOilPublicKey ];
        };
        carol = {
          isNormalUser = true;
          openssh.authorizedKeys.keys = [ sshKeys.snakeOilPublicKey ];
        };
      };

      my = {
        secrets = {
          file = ./fixtures/secrets.yaml;
          sshKeyPath = "${sshKeys.snakeOilEd25519PrivateKey}";
        };
        sshServer.enable = true;
        hardened = {
          enable = true;
          sshUsers = [ "alice" ];
          # The test network is 192.168.1.0/24: the client is a stranger.
          neverBan = [ "10.*" ];
        };
      };
    };

    client = { };
  };

  testScript =
    { nodes, ... }:
    let
      isHome = lib.head (
        lib.splitString " " nodes.server.services.fail2ban.jails.DEFAULT.settings.ignorecommand
      );
    in
    ''
      start_all()
      server.wait_for_unit("sshd.service")
      server.wait_for_unit("fail2ban.service")
      client.succeed("install -m 600 ${sshKeys.snakeOilPrivateKey} /root/key")

      with subtest("root has the password of the sops file, and there is no sudo"):
          shadow = server.succeed("getent shadow root").split(":")[1]
          server.succeed(f"${checkPassword} open-sesame-root '{shadow}'")
          server.fail("command -v sudo")

      with subtest("the home network is never banned, a stranger may be"):
          server.succeed("${isHome} 10.1.2.3")
          server.fail("${isHome} 192.168.1.2")
          server.fail("${isHome} 110.1.2.3")

      with subtest("only the listed user logs in"):
          client.succeed("${ssh} alice@server true")
          client.fail("${ssh} carol@server true")

      with subtest("who keeps failing is banned"):
          client.fail("${ssh} carol@server true")
          client.fail("${ssh} carol@server true")
          server.wait_until_succeeds("fail2ban-client status sshd | grep -E 'Banned IP list:.*[0-9]'")
          server.wait_until_succeeds("iptables -S | grep -E 'f2b-sshd.*(REJECT|DROP)'")
          # A banned connection may hang instead of being refused.
          client.fail("timeout 20 ${ssh} -o ConnectTimeout=5 alice@server true")
    '';
}
