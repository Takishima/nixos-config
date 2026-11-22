{ config, lib, ... }:
let
  cfg = config.my.onePassword;
in
{
  options.my.onePassword = {
    enable = lib.mkEnableOption "1Password GUI and CLI";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users who may unlock 1Password through polkit (system authentication, CLI integration).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      _1password.enable = true;
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = cfg.users;
      };
    };
  };
}
