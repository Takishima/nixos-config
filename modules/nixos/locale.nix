{ config, lib, ... }:
let
  cfg = config.my.locale;
in
{
  options.my.locale = {
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
    };
    default = lib.mkOption {
      type = lib.types.str;
      default = "en_GB.UTF-8";
      description = "Language of messages.";
    };
    formats = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Locale for dates, numbers, money and paper, when it differs from `default`.";
    };
    consoleKeyMap = lib.mkOption {
      type = lib.types.str;
      default = "us";
    };
    xkb = {
      layout = lib.mkOption {
        type = lib.types.str;
        default = "us";
      };
      variant = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };

  config = {
    time.timeZone = cfg.timeZone;

    i18n = {
      defaultLocale = cfg.default;
      extraLocaleSettings = lib.mkIf (cfg.formats != null) (
        lib.genAttrs [
          "LC_ADDRESS"
          "LC_IDENTIFICATION"
          "LC_MEASUREMENT"
          "LC_MONETARY"
          "LC_NAME"
          "LC_NUMERIC"
          "LC_PAPER"
          "LC_TELEPHONE"
          "LC_TIME"
        ] (_: cfg.formats)
      );
    };

    console = {
      keyMap = cfg.consoleKeyMap;
      earlySetup = true;
    };

    services.xserver.xkb = { inherit (cfg.xkb) layout variant; };
  };
}
