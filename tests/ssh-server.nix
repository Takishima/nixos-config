# my.sshServer: a user's key logs in, passwords and root do not. The server
# imports every module with no sops file, as a freshly installed host would.
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
in
{
  name = "ssh-server";

  nodes = {
    server = {
      imports = [ self.nixosModules.default ];

      my.sshServer.enable = true;

      # Root has the key too, so only PermitRootLogin keeps it out.
      users.users = {
        alice = {
          isNormalUser = true;
          openssh.authorizedKeys.keys = [ sshKeys.snakeOilPublicKey ];
        };
        root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilPublicKey ];
      };
    };

    client =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.sshpass ];
      };
  };

  testScript = ''
    start_all()
    server.wait_for_unit("sshd.service")
    server.wait_for_open_port(22)
    client.wait_for_unit("network.target")

    client.succeed("install -m 600 ${sshKeys.snakeOilPrivateKey} /root/key")
    ssh = "ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    with_key = f"{ssh} -o BatchMode=yes -i /root/key"

    with subtest("the user's key logs in"):
        assert client.succeed(f"{with_key} alice@server whoami").strip() == "alice"

    with subtest("root is refused, even with an authorized key"):
        client.fail(f"{with_key} root@server true")

    with subtest("the password is refused, although it is the right one"):
        # Without a sops file the user has the initial password.
        shadow = server.succeed("getent shadow alice").split(":")[1]
        server.succeed(f"${checkPassword} changeme '{shadow}'")
        status, out = client.execute(
            f"sshpass -p changeme {ssh} -o PubkeyAuthentication=no alice@server true 2>&1"
        )
        assert status != 0, out
        assert "Permission denied (publickey)" in out, out
  '';
}
