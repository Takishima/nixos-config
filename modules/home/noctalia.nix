{
  config,
  lib,
  ...
}:
let
  cfg = config.my.desktop.noctalia;
  inherit (config.my.desktop.niri.lib) spawn;
  niri = lib.getExe config.programs.niri.package;

  msg =
    title: args:
    spawn title (
      [
        "noctalia"
        "msg"
      ]
      ++ args
    );
  panel = title: args: msg title ([ "panel-toggle" ] ++ args) // { repeat = false; };
in
{
  imports = [ ./niri.nix ];

  options.my.desktop.noctalia = {
    enable = lib.mkEnableOption "the Noctalia shell" // {
      default = config.my.desktop.niri.enable;
      defaultText = lib.literalExpression "config.my.desktop.niri.enable";
    };

    lockAfter = lib.mkOption {
      type = lib.types.ints.positive;
      default = 600;
      description = "Idle seconds before the screen locks. The monitors turn off a minute later.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      luciole.enable = true;

      noctalia = {
        enable = true;
        systemd.enable = true;
        settings = {
          theme.templates = {
            enable_builtin_templates = true;
            builtin_ids = [ "luciole" ];
          };
          shell.session.actions = [
            { action = "lock"; }
            { action = "logout"; }
            { action = "suspend"; }
            { action = "reboot"; }
            { action = "shutdown"; }
          ];
          idle = {
            behavior_order = [
              "lock"
              "screen-off"
            ];
            behavior.lock = {
              timeout = cfg.lockAfter;
              action = "lock";
            };
            behavior.screen-off = {
              timeout = cfg.lockAfter + 60;
              action = "command";
              command = "${niri} msg action power-off-monitors";
            };
          };
        };
      };

      # Noctalia's notification actions raise windows without a valid activation token.
      niri.settings.debug.honor-xdg-activation-with-invalid-serial = [ ];
    };

    my.desktop.niri.extraBinds = {
      "Mod+Space" = panel "Launcher" [ "launcher" ];
      "Mod+W" = panel "Windows" [
        "launcher"
        "/win"
      ];
      "Mod+V" = panel "Clipboard" [ "clipboard" ];
      "Mod+X" = panel "Power menu" [ "session" ];
      "XF86Calculator" = panel "Calculator" [
        "launcher"
        "/calc"
      ];
      "Mod+N" = panel "Notification history" [
        "control-center"
        "notifications"
      ];
      "Mod+Ctrl+N" = msg "Dismiss all notifications" [ "notification-clear-active" ];
      "Mod+Ctrl+Shift+N" = msg "Toggle do-not-disturb" [ "notification-dnd-toggle" ];

      "Mod+S" = msg "Screenshot region" [ "screenshot-region" ];
      "Print" = msg "Screenshot region" [ "screenshot-region" ];
      "Mod+Shift+S" = msg "Screenshot window" [ "screenshot-window" ];
      "Mod+Ctrl+S" = msg "Screenshot screen" [ "screenshot-fullscreen" ];
    };
  };
}
