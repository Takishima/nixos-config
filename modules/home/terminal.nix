{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.terminal.enable = lib.mkEnableOption "kitty";

  config = lib.mkIf config.my.terminal.enable {
    programs.kitty = {
      enable = true;
      shellIntegration.enableFishIntegration = true;

      settings = {
        shell = lib.mkIf config.programs.fish.enable (lib.getExe pkgs.fish);

        font_family = "JetBrains Mono";
        font_size = 11;

        window_padding_width = 4;
        hide_window_decorations = "yes";
        confirm_os_window_close = 0;
        background_opacity = "0.95";

        scrollback_lines = 10000;
        enable_audio_bell = false;
        cursor_shape = "beam";
        cursor_blink_interval = 0;

        tab_bar_min_tabs = 1;
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_title_template = "{index}: {tab.active_wd.rsplit('/', 1)[-1] if tab.active_wd else title}";
      };

      keybindings = {
        "ctrl+shift+t" = "new_tab_with_cwd";
        "ctrl+shift+q" = "close_tab";
        "ctrl+shift+right" = "next_tab";
        "ctrl+shift+left" = "previous_tab";
        "ctrl+shift+enter" = "new_window_with_cwd";
        "ctrl+shift+w" = "close_window";
        "ctrl+plus" = "change_font_size all +1.0";
        "ctrl+minus" = "change_font_size all -1.0";
        "ctrl+0" = "change_font_size all 0";
      };
    };
  };
}
