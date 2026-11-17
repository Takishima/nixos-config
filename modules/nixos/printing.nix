{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.printing;

  # cups-filters ships these outside the directory CUPS reads models from.
  genericPcl6 = pkgs.runCommand "generic-pcl6-ppds" { } ''
    install -Dm444 -t $out/share/cups/model ${pkgs.cups-filters}/share/ppd/cupsfilters/pxl{mono,color}.ppd
  '';
in
{
  options.my.printing = {
    enable = lib.mkEnableOption "CUPS, finding network printers over mDNS";

    printers = lib.mkOption {
      default = { };
      description = "Print queues to create, by name.";
      example = {
        office = {
          uri = "socket://192.0.2.10:9100";
          model = "pxlmono.ppd";
        };
      };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            uri = lib.mkOption {
              type = lib.types.str;
              description = "Device URI, as `lpinfo -v` shows them.";
            };
            model = lib.mkOption {
              type = lib.types.str;
              default = "everywhere";
              description = ''
                Driver, as `lpinfo -m` shows them. `pxlmono.ppd` and
                `pxlcolor.ppd` are generic PCL 6. `everywhere` is driverless
                IPP, which needs the printer reachable when the queue is created.
              '';
            };
            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            location = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            options = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              example = {
                PageSize = "A4";
              };
              description = "PPD options, as `lpoptions -l` shows them.";
            };
          };
        }
      );
    };

    default = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Name of the default queue.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      printing = {
        enable = true;
        drivers = [ genericPcl6 ];
      };
      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    };

    hardware.printers = {
      ensureDefaultPrinter = cfg.default;
      ensurePrinters = lib.mapAttrsToList (name: p: {
        inherit name;
        inherit (p) model description location;
        deviceUri = p.uri;
        ppdOptions = p.options;
      }) cfg.printers;
    };
  };
}
