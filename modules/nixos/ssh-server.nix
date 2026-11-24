{ config, lib, ... }:
{
  options.my.sshServer.enable = lib.mkEnableOption ''
    the OpenSSH server, with key-only logins. The keys are each user's
    `users.users.<name>.openssh.authorizedKeys.keys`'';

  config = lib.mkIf config.my.sshServer.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        MaxAuthTries = 3;
        LoginGraceTime = 60;
      };
    };
  };
}
