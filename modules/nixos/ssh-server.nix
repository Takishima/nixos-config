{ config, lib, ... }:
let
  cfg = config.my.sshServer;
in
{
  imports = [ ./user.nix ];

  options.my.sshServer = {
    enable = lib.mkEnableOption "the OpenSSH server, with key-only logins";

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Public keys that may log in as the user.";
    };
  };

  config = lib.mkIf cfg.enable {
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

    users.users.${config.my.user.name}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
  };
}
