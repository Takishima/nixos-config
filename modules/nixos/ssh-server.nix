{ config, lib, ... }:
{
  imports = [ ./post-switch.nix ];

  options.my.sshServer.enable = lib.mkEnableOption ''
    the OpenSSH server, with key-only logins. The keys are each user's
    `users.users.<name>.openssh.authorizedKeys.keys`. A switch that stops
    sshd fails `my.postSwitch.checks`'';

  config = lib.mkIf config.my.sshServer.enable {
    my.postSwitch.checks.sshd = "systemctl is-active --quiet sshd.service";

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
