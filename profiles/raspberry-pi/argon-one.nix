# The fan of an Argon One case, which stays off unless told a speed over I2C:
# https://github.com/Argon40Tech/Argon-ONE-i2c-Codes
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.argonOne;
in
{
  options.my.argonOne = {
    enable = lib.mkEnableOption "the fan of an Argon One case";

    curve = lib.mkOption {
      type = lib.types.attrsOf (lib.types.ints.between 0 100);
      default = {
        "55" = 30;
        "60" = 55;
        "65" = 100;
      };
      description = "Fan speed in percent from each temperature in °C. The default is Argon's.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.i2c.enable = true;
    hardware.raspberry-pi.configtxt.settings.all.dtparam = [ "i2c_arm=on" ];

    systemd.services.argon-one-fan = {
      description = "Argon One case fan";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.i2c-tools ];
      serviceConfig.Restart = "always";
      script = ''
        set -u
        speed=-1
        cool=0
        while true; do
          temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
          want=0
          ${lib.concatMapStrings
            (step: ''
              if [ "$temp" -ge ${toString step.at} ]; then want=${toString step.percent}; fi
            '')
            (
              lib.sort (a: b: a.at < b.at) (
                lib.mapAttrsToList (at: percent: {
                  at = lib.toInt at;
                  inherit percent;
                }) cfg.curve
              )
            )
          }
          # Speed up at once, slow down only after 30 seconds below the step.
          if [ "$want" -lt "$speed" ]; then
            cool=$((cool + 1))
            if [ "$cool" -lt 3 ]; then want=$speed; fi
          else
            cool=0
          fi
          if [ "$want" -ne "$speed" ]; then
            i2cset -y 1 0x1a "$want" && speed=$want
          fi
          sleep 10
        done
      '';
      # A stopped service must not leave the fan off.
      postStop = "i2cset -y 1 0x1a 100 || true";
    };
  };
}
