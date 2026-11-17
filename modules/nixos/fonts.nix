{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.fonts;
in
{
  options.my.fonts = {
    enable = lib.mkEnableOption "the desktop font set: Inter, JetBrains Mono, Noto, Nerd Font symbols";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Fonts on top of that set.";
    };
  };

  config = lib.mkIf cfg.enable {
    fonts = {
      enableDefaultPackages = true;
      packages =
        (with pkgs; [
          jetbrains-mono
          inter
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          nerd-fonts.symbols-only
          nerd-fonts.jetbrains-mono
        ])
        ++ cfg.packages;
      fontconfig.defaultFonts = {
        sansSerif = [ "Inter" ];
        monospace = [ "JetBrains Mono" ];
      };
    };
  };
}
