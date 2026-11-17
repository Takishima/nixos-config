{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.niri;
in
{
  imports = [ ./fonts.nix ];

  options.my.desktop.niri.enable =
    lib.mkEnableOption "the niri Wayland session, with a greetd login screen";

  config = lib.mkIf cfg.enable {
    my.fonts.enable = true;

    programs.niri.enable = true;

    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = "${lib.getExe pkgs.tuigreet} --time --remember --asterisks --cmd niri-session";
    };

    # niri starts no polkit agent of its own.
    security.soteria.enable = true;

    services = {
      gnome.gnome-keyring.enable = true;
      gvfs.enable = true;
      udisks2.enable = true;
      upower.enable = true;
      power-profiles-daemon.enable = true;
    };

    environment = {
      sessionVariables.NIXOS_OZONE_WL = "1";
      systemPackages = with pkgs; [
        xwayland-satellite
        wl-clipboard
        playerctl
        libnotify
      ];
    };
  };
}
