{ config, lib, ... }:
let
  cfg = config.my.wifi;
  secret = name: "wifi/${name}";
  envVar = name: "WIFI_${lib.toUpper name}";
  networks = lib.filterAttrs (name: _: config.my.secrets.has (secret name)) cfg.networks;
  missing = lib.attrNames (lib.removeAttrs cfg.networks (lib.attrNames networks));
  unit = "NetworkManager-ensure-profiles.service";
in
{
  imports = [ ./secrets.nix ];

  options.my.wifi.networks = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          ssid = lib.mkOption {
            type = lib.types.str;
            description = "The network's name, also the profile's name.";
          };
          keyMgmt = lib.mkOption {
            type = lib.types.enum [
              "wpa-psk"
              "sae"
            ];
            default = "wpa-psk";
            description = "`wpa-psk` for WPA2, `sae` for WPA3.";
          };
          band = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "a"
                "bg"
              ]
            );
            default = null;
            description = "Pins the profile to 5 GHz (`a`) or 2.4 GHz (`bg`).";
          };
        };
      }
    );
    default = { };
    description = ''
      NetworkManager Wi-Fi profiles. The attribute name is the password's key
      under `wifi` in the sops file; a network without one gets no profile.
    '';
  };

  config = {
    warnings = lib.optional (missing != [ ]) (
      "my.wifi.networks has no password under wifi in the sops file for: "
      + lib.concatStringsSep ", " missing
    );

    sops.secrets = lib.mapAttrs' (name: _: lib.nameValuePair (secret name) { }) networks;

    sops.templates."wifi.env" = lib.mkIf (networks != { }) {
      content = lib.concatMapStringsSep "\n" (
        name: "${envVar name}=${config.sops.placeholder.${secret name}}"
      ) (lib.attrNames networks);
      restartUnits = [ unit ];
    };

    networking.networkmanager.ensureProfiles = lib.mkIf (networks != { }) {
      environmentFiles = [ config.sops.templates."wifi.env".path ];
      profiles = lib.mapAttrs (name: n: {
        connection = {
          id = n.ssid;
          type = "wifi";
        };
        wifi = {
          mode = "infrastructure";
          inherit (n) ssid;
        }
        // lib.optionalAttrs (n.band != null) { inherit (n) band; };
        wifi-security = {
          key-mgmt = n.keyMgmt;
          psk = "$" + envVar name;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      }) networks;
    };
  };
}
