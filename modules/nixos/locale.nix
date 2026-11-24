# Time zone, locales and keyboard layouts.
{ config, lib, ... }:
let
  cfg = config.my.locale;
in
{
  options.my.locale = {
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = ''
        Time zone, as a tz database name. `my.autoUpgrade.dates` and
        `rebootWindow` are times in it.
      '';
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
      description = "Keyboard layout of the text console.";
    };
    xkb = {
      layout = lib.mkOption {
        type = lib.types.str;
        default = "us";
        description = "Keyboard layout of the graphical session, as an XKB layout.";
      };
      variant = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Variant of `layout`; empty for its default.";
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
