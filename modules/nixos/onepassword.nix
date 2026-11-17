{ config, lib, ... }:
{
  imports = [ ./user.nix ];

  options.my.onePassword.enable = lib.mkEnableOption "1Password GUI and CLI";

  config = lib.mkIf config.my.onePassword.enable {
    programs = {
      _1password.enable = true;
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = [ config.my.user.name ];
      };
    };
  };
}
