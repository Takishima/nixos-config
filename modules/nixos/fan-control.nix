# CoolerControl applies fan curves; they live in /etc/coolercontrol.
{
  config,
  lib,
  ...
}:
let
  cfg = config.my.fanControl;
in
{
  options.my.fanControl = {
    enable = lib.mkEnableOption "fan control with CoolerControl";

    it87 = lib.mkEnableOption ''
      the out-of-tree it87 driver. The in-kernel one lacks several ITE Super
      I/O chips, among them the IT8688E that drives most fan headers of
      Gigabyte X570 boards, so those headers are missing without it'';
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { programs.coolercontrol.enable = true; }

      (lib.mkIf cfg.it87 {
        boot = {
          extraModulePackages = [ config.boot.kernelPackages.it87 ];
          kernelModules = [ "it87" ];
          # Narrower than acpi_enforce_resources=lax.
          extraModprobeConfig = ''
            options it87 ignore_resource_conflict=1
          '';
        };
      })
    ]
  );
}
