# niri binds match unshifted keysyms: on the Swiss layout egrave/diaeresis are
# the brackets, asciicircum is Equal, eacute SemiColon, apostrophe Slash.
{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.niri;
  inherit (config.lib.niri) actions;

  spawn = title: argv: {
    action = actions.spawn argv;
    hotkey-overlay.title = title;
  };
  media = title: argv: spawn title argv // { allow-when-locked = true; };

  workspaceBinds = lib.mergeAttrsList (
    map (n: {
      "Mod+${toString n}".action = actions.focus-workspace n;
      "Mod+Shift+${toString n}".action.move-window-to-workspace = n;
      "Mod+Ctrl+${toString n}".action.move-column-to-workspace = n;
    }) (lib.range 1 9)
  );

  directional =
    prefix: actionsByKeys:
    lib.mergeAttrsList (
      lib.mapAttrsToList (
        keys: action:
        lib.genAttrs (map (k: "${prefix}${k}") (lib.splitString " " keys)) (_: {
          inherit action;
        })
      ) actionsByKeys
    );
in
{
  imports = [ ./onepassword.nix ];

  options.my.desktop.niri = {
    enable = lib.mkEnableOption "the niri configuration" // {
      default = osConfig.my.desktop.niri.enable or false;
      defaultText = lib.literalExpression "osConfig.my.desktop.niri.enable";
    };

    outputs = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        "DP-1".position = {
          x = 2560;
          y = 0;
        };
      };
      description = "Monitor layout, as programs.niri.settings.outputs.";
    };

    xkb = {
      layout = lib.mkOption {
        type = lib.types.str;
        default = osConfig.services.xserver.xkb.layout or "us";
        defaultText = lib.literalExpression "osConfig.services.xserver.xkb.layout";
      };
      variant = lib.mkOption {
        type = lib.types.str;
        default = osConfig.services.xserver.xkb.variant or "";
        defaultText = lib.literalExpression "osConfig.services.xserver.xkb.variant";
      };
    };

    extraBinds = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Bindings from other modules, as programs.niri.settings.binds.";
    };

    lib = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Helpers for `extraBinds`: spawn and media take a title and an argv.";
    };
  };

  config = lib.mkIf cfg.enable {
    my.desktop.niri.lib = { inherit spawn media; };

    wayland.systemd.target = "niri.service";

    home.packages = [ pkgs.pwvucontrol ];

    services.swayosd.enable = true;

    programs.niri = {
      package = osConfig.programs.niri.package or pkgs.niri;

      settings = {
        inherit (cfg) outputs;

        input = {
          keyboard = {
            xkb = { inherit (cfg.xkb) layout variant; };
            repeat-delay = 200;
            repeat-rate = 40;
          };
          mouse = {
            accel-profile = "flat";
            accel-speed = 0.3;
          };
        };

        prefer-no-csd = true;
        hotkey-overlay.skip-at-startup = true;
        gestures.hot-corners.enable = false;

        layout = {
          gaps = 8;
          focus-ring = {
            width = 4;
            urgent.color = "#9b0000";
          };
          default-column-width.proportion = 0.5;
          preset-column-widths = [
            { proportion = 1. / 3.; }
            { proportion = 1. / 2.; }
            { proportion = 2. / 3.; }
          ];
        };

        spawn-at-startup =
          # The SSH agent lives in the GUI app; --silent keeps it in the tray.
          lib.optional config.my.onePassword.enable {
            argv = [
              "1password"
              "--silent"
            ];
          }
          # Owns blueman's pairing agent; without it BlueZ rejects pairing.
          ++ lib.optional (osConfig.services.blueman.enable or false) { argv = [ "blueman-applet" ]; };

        window-rules = [
          {
            geometry-corner-radius = lib.genAttrs [ "top-left" "top-right" "bottom-left" "bottom-right" ] (
              _: 2.0
            );
            clip-to-geometry = true;
          }
          {
            matches = [
              { app-id = "^pinentry"; }
              { app-id = "^mpv$"; }
              { app-id = "pwvucontrol$"; }
              {
                app-id = "firefox$";
                title = "^(Picture-in-Picture|Library)$";
              }
            ];
            open-floating = true;
          }
          {
            matches = [ { app-id = "^floating\\.kitty$"; } ];
            open-floating = true;
            default-column-width.proportion = 0.33;
            default-window-height.proportion = 0.5;
          }
          {
            matches = [ { app-id = "^1[Pp]assword$"; } ];
            block-out-from = "screencast";
          }
        ];

        binds =
          workspaceBinds
          // directional "Mod+" {
            "Left H" = actions.focus-column-left;
            "Down J" = actions.focus-window-down;
            "Up K" = actions.focus-window-up;
            "Right L" = actions.focus-column-right;
          }
          // directional "Mod+Ctrl+" {
            "Left H" = actions.move-column-left;
            "Down J" = actions.move-window-down;
            "Up K" = actions.move-window-up;
            "Right L" = actions.move-column-right;
          }
          // directional "Mod+Shift+" {
            "Left H" = actions.focus-monitor-left;
            "Down J" = actions.focus-monitor-down;
            "Up K" = actions.focus-monitor-up;
            "Right L" = actions.focus-monitor-right;
          }
          // directional "Mod+Ctrl+Shift+" {
            "Left H" = actions.move-column-to-monitor-left;
            "Down J" = actions.move-column-to-monitor-down;
            "Up K" = actions.move-column-to-monitor-up;
            "Right L" = actions.move-column-to-monitor-right;
          }
          // {
            "Mod+Shift+apostrophe".action = actions.show-hotkey-overlay;
            "Mod+O" = {
              action = actions.toggle-overview;
              repeat = false;
            };

            "Mod+Alt+L" = spawn "Lock screen" [
              "loginctl"
              "lock-session"
            ];
            "Mod+Shift+Alt+L".action = actions.power-off-monitors;
            "Mod+Ctrl+Shift+Q".action = actions.quit;
            "Mod+E" = {
              action = actions.set-dynamic-cast-window;
              hotkey-overlay.title = "Cast focused window";
            };

            "XF86AudioRaiseVolume" = media "Raise volume" [
              "swayosd-client"
              "--output-volume"
              "raise"
            ];
            "XF86AudioLowerVolume" = media "Lower volume" [
              "swayosd-client"
              "--output-volume"
              "lower"
            ];
            "XF86AudioMute" = media "Mute playback" [
              "swayosd-client"
              "--output-volume"
              "mute-toggle"
            ];
            "XF86AudioMicMute" = media "Mute microphone" [
              "swayosd-client"
              "--input-volume"
              "mute-toggle"
            ];
            "XF86AudioPlay" = media "Play / pause" [
              "playerctl"
              "play-pause"
            ];
            "XF86AudioStop" = media "Stop" [
              "playerctl"
              "stop"
            ];
            "XF86AudioPrev" = media "Previous track" [
              "playerctl"
              "previous"
            ];
            "XF86AudioNext" = media "Next track" [
              "playerctl"
              "next"
            ];

            "Mod+Alt+T" = spawn "Terminal" [ "kitty" ];
            "Mod+Alt+Shift+T" = spawn "Terminal (floating)" [
              "kitty"
              "--class=floating.kitty"
            ];
            "Mod+Alt+E" = spawn "Emacs" [
              "emacsclient"
              "-c"
              "-a"
              ""
            ];
            "Mod+Alt+F" = spawn "File manager" [ "luciole" ];
            "Mod+Alt+A" = spawn "Sound devices" [ "pwvucontrol" ];
            "Mod+Alt+B" = spawn "Browser" [ "firefox" ];
            "Mod+Alt+Shift+B" = spawn "Browser (private)" [
              "firefox"
              "-private-window"
            ];

            "Mod+Q" = {
              action = actions.close-window;
              repeat = false;
            };
            "Mod+C".action = actions.center-column;
            "Mod+Ctrl+C".action = actions.center-visible-columns;
            "Mod+Z".action = actions.toggle-window-floating;
            "Mod+Ctrl+Z".action = actions.switch-focus-between-floating-and-tiling;
            "Mod+T".action = actions.toggle-column-tabbed-display;

            "Mod+egrave".action = actions.consume-or-expel-window-left;
            "Mod+diaeresis".action = actions.consume-or-expel-window-right;
            "Mod+Comma".action = actions.consume-window-into-column;
            "Mod+Period".action = actions.expel-window-from-column;

            "Mod+F".action = actions.maximize-column;
            "Mod+Shift+F".action = actions.fullscreen-window;
            "Mod+Ctrl+F".action = actions.expand-column-to-available-width;
            "Mod+A".action = actions.switch-preset-column-width;
            "Mod+Shift+R".action = actions.switch-preset-window-height;
            "Mod+Ctrl+R".action = actions.reset-window-height;
            "Mod+asciicircum".action = actions.set-column-width "+10%";
            "Mod+Minus".action = actions.set-column-width "-10%";
            "Mod+Shift+asciicircum".action = actions.set-window-height "+10%";
            "Mod+Shift+Minus".action = actions.set-window-height "-10%";

            "Mod+I".action = actions.focus-window-previous;
            "Mod+G".action = actions.focus-column-first;
            "Mod+eacute".action = actions.focus-column-last;
            "Mod+Ctrl+G".action = actions.move-column-to-first;
            "Mod+Ctrl+eacute".action = actions.move-column-to-last;
            "Mod+Home".action = actions.focus-column-first;
            "Mod+End".action = actions.focus-column-last;
            "Mod+Ctrl+Home".action = actions.move-column-to-first;
            "Mod+Ctrl+End".action = actions.move-column-to-last;

            "Mod+WheelScrollDown".action = actions.focus-column-right;
            "Mod+WheelScrollUp".action = actions.focus-column-left;
            "Mod+Ctrl+WheelScrollDown".action = actions.move-column-right;
            "Mod+Ctrl+WheelScrollUp".action = actions.move-column-left;
            "Mod+Shift+WheelScrollDown" = {
              action = actions.focus-workspace-down;
              cooldown-ms = 150;
            };
            "Mod+Shift+WheelScrollUp" = {
              action = actions.focus-workspace-up;
              cooldown-ms = 150;
            };

            "Mod+D".action = actions.focus-workspace-down;
            "Mod+U".action = actions.focus-workspace-up;
            "Mod+Page_Down".action = actions.focus-workspace-down;
            "Mod+Page_Up".action = actions.focus-workspace-up;
            "Mod+Ctrl+D".action = actions.move-column-to-workspace-down;
            "Mod+Ctrl+U".action = actions.move-column-to-workspace-up;
            "Mod+Shift+D".action = actions.move-workspace-down;
            "Mod+Shift+U".action = actions.move-workspace-up;

            "Mod+Escape" = {
              action = actions.toggle-keyboard-shortcuts-inhibit;
              allow-inhibiting = false;
            };
          }
          // lib.optionalAttrs config.my.onePassword.enable {
            "Mod+Alt+P" = spawn "Passwords" [ "1password" ];
            "Ctrl+Shift+Space" = spawn "1Password Quick Access" [
              "1password"
              "--quick-access"
            ];
          }
          // cfg.extraBinds;
      };
    };
  };
}
