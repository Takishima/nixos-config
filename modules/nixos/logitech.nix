{ config, lib, ... }:
let
  cfg = config.my.logitech;
in
{
  options.my.logitech = {
    enable = lib.mkEnableOption "Solaar for Logitech receivers and mice (MX Master)";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users in the uinput group, which Solaar's rules need.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.uinput.enable = true;
    users.groups.uinput.members = cfg.users;
    programs.solaar = {
      enable = true;
      userService.enable = true;
    };
  };
}
