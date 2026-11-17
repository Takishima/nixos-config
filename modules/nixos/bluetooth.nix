{ config, lib, ... }:
{
  options.my.bluetooth.enable = lib.mkEnableOption "Bluetooth, with blueman as pairing agent";

  config = lib.mkIf config.my.bluetooth.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;
  };
}
