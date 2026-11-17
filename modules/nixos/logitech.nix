{ config, lib, ... }:
{
  imports = [ ./user.nix ];

  options.my.logitech.enable = lib.mkEnableOption "Solaar for Logitech receivers and mice (MX Master)";

  config = lib.mkIf config.my.logitech.enable {
    hardware.uinput.enable = true;
    my.user.extraGroups = [ "uinput" ];
    programs.solaar = {
      enable = true;
      userService.enable = true;
    };
  };
}
