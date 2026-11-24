{ config, lib, ... }:
{
  imports = [ ./auto-upgrade.nix ];

  options.my.sshServer.enable = lib.mkEnableOption ''
    the OpenSSH server, with key-only logins. The keys are each user's
    `users.users.<name>.openssh.authorizedKeys.keys`. With `my.autoUpgrade`,
    an upgrade that stops sshd is rolled back'';

  config = lib.mkIf config.my.sshServer.enable {
    my.autoUpgrade.checks.sshd = "systemctl is-active --quiet sshd.service";

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
