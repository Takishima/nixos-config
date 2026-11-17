{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.spelling;
in
{
  options.my.spelling = {
    enable = lib.mkEnableOption "spell checking dictionaries";

    aspell = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "en" ];
      description = "Dictionaries for aspell (Emacs), as attributes of pkgs.aspellDicts.";
    };

    hunspell = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "en_GB-ise" ];
      description = "Dictionaries for hunspell (LibreOffice, Thunderbird), as attributes of pkgs.hunspellDicts.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.aspellWithDicts (dicts: map (name: dicts.${name}) cfg.aspell))
      (pkgs.hunspell.withDicts (dicts: map (name: dicts.${name}) cfg.hunspell))
    ];
  };
}
