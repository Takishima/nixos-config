{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.smartcard;
in
{
  options.my.smartcard = {
    enable = lib.mkEnableOption "PC/SC for smart card and NFC readers, with the ACS driver";
    yubikey = lib.mkEnableOption "YubiKey udev rules, ykman and Yubico Authenticator";
  };

  config = lib.mkIf cfg.enable {
    services.pcscd = {
      enable = true;
      plugins = [ pkgs.acsccid ];
    };
    services.udev.packages = lib.mkIf cfg.yubikey [ pkgs.yubikey-personalization ];
    environment.systemPackages = [
      pkgs.pcsc-tools
    ]
    ++ lib.optionals cfg.yubikey [
      pkgs.yubikey-manager
      pkgs.yubioath-flutter
    ];
  };
}
