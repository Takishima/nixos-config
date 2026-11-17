{ config, lib, ... }:
{
  options.my.audio.enable = lib.mkEnableOption "PipeWire audio";

  config = lib.mkIf config.my.audio.enable {
    security.rtkit.enable = true;
    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    };
  };
}
