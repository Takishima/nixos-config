# The fan of an Argon One case, which stays off unless told a speed over I2C:
# https://github.com/Argon40Tech/Argon-ONE-i2c-Codes
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  sandbox = import ../../lib/service-sandbox.nix;
in
{
  options.my.argonOne.enable = lib.mkEnableOption "the fan of an Argon One case, at the speeds of Argon's own daemon";

  config = lib.mkIf config.my.argonOne.enable {
    ${if options.my ? postSwitch then "my" else null}.postSwitch.checks.argon-one-fan =
      "systemctl is-active --quiet argon-one-fan.service";

    hardware.i2c.enable = true;
    hardware.raspberry-pi.configtxt.settings.all.dtparam = [ "i2c_arm=on" ];

    systemd.services.argon-one-fan = {
      description = "Argon One case fan";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.i2c-tools ];
      serviceConfig = sandbox.unprivileged // {
        Restart = "always";
        DynamicUser = true;
        SupplementaryGroups = [ config.hardware.i2c.group ];
        DevicePolicy = "closed";
        DeviceAllow = "/dev/i2c-1 rw";
        PrivateNetwork = true;
        RestrictAddressFamilies = "none";
      };
      script = ''
        set -u
        speed=-1
        cool=0
        while true; do
          temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
          want=0
          if [ "$temp" -ge 55 ]; then want=30; fi
          if [ "$temp" -ge 60 ]; then want=55; fi
          if [ "$temp" -ge 65 ]; then want=100; fi
          # Speed up at once, slow down only at the third reading below the step.
          if [ "$want" -lt "$speed" ]; then
            cool=$((cool + 1))
            if [ "$cool" -lt 3 ]; then want=$speed; fi
          else
            cool=0
          fi
          if [ "$want" -ne "$speed" ]; then
            i2cset -y 1 0x1a "$want"
            speed=$want
          fi
          sleep 10
        done
      '';
      # A stopped service must not leave the fan off.
      postStop = "i2cset -y 1 0x1a 100 || true";
    };
  };
}
