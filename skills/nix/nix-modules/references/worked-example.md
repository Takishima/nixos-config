# Worked example — service module

A complete NixOS service module suitable as a starting template. Covers
enable/disable, user/group creation, config-file generation, conditional
extra features, and systemd hardening.

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myapp;

  configFile = pkgs.writeText "myapp.conf" ''
    port = ${toString cfg.port}
    host = ${cfg.host}
    log_level = ${cfg.logLevel}
  '';
in
{
  options.services.myapp = {
    enable = lib.mkEnableOption "MyApp service";

    package = lib.mkPackageOption pkgs "myapp" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Host address to bind to";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "debug" "info" "warn" "error" ];
      default = "info";
      description = "Logging level";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "myapp";
      description = "User to run the service as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "myapp";
      description = "Group to run the service as";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/myapp";
      description = "Directory for application data";
    };

    enableMetrics = lib.mkEnableOption "Prometheus metrics endpoint";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      systemd.services.myapp = {
        description = "MyApp Service";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = "${cfg.package}/bin/myapp --config ${configFile}";
          Restart = "on-failure";
          RestartSec = "5s";

          # Hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ cfg.dataDir ];
        };
      };

      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = true;
      };

      users.groups.${cfg.group} = { };
    }

    (lib.mkIf (cfg.logLevel == "debug") {
      systemd.services.myapp.environment.DEBUG = "1";
    })

    (lib.mkIf cfg.enableMetrics {
      systemd.services.myapp.environment.METRICS_PORT = "9100";
      networking.firewall.allowedTCPPorts = [ 9100 ];
    })
  ]);
}
```

## What to keep / drop when adapting

- The systemd hardening block (`NoNewPrivileges`, `ProtectSystem`, etc.) is
  worth keeping by default. Loosen only when the service genuinely needs
  more access — `ReadWritePaths` is usually the right escape hatch.
- `mkPackageOption` lets users swap the package without touching the rest
  of the config. Always preferable to a hard-coded `pkgs.myapp` in
  `ExecStart`.
- The `enableMetrics` sub-flag is a template for any optional feature: gate
  its config block on `mkIf cfg.enableMetrics` inside the outer `mkMerge`.
- For a home-manager (user-level) service the shape is the same, but you
  declare `systemd.user.services.*` instead of `systemd.services.*` and
  skip the `users.users.*` / `users.groups.*` block — the user already
  exists.
