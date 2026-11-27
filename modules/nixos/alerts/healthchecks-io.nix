# Pings a healthchecks.io check when a unit succeeds, and reports one that fails.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.alerts.healthchecksIo;
  sandbox = import ../../../lib/service-sandbox.nix;
  secret = "healthchecks/url";
  hasUrl = config.my.secrets.has secret;
  url = config.sops.secrets.${secret}.path;

  socket = "/run/healthchecks-ping.sock";
  giveUpSeconds = 600;

  ping = pkgs.writeShellApplication {
    name = "healthchecks-ping";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.socat
    ];
    text = ''
      suffix=$1
      title=$2
      answer=$({
        echo "$suffix"
        echo "$title"
        tail -c 10000
      } | socat -t ${toString (giveUpSeconds + 60)} - UNIX-CONNECT:${socket})
      if [ "$answer" != sent ]; then
        echo "healthchecks-ping: not sent, see the journal of healthchecks-ping@*.service" >&2
        exit 1
      fi
    '';
  };

  send = pkgs.writeShellApplication {
    name = "healthchecks-send";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      read -r suffix
      # Not as an argument, which every user can read: the URL is a secret.
      curl --config <(printf 'url = "%s%s"\n' "$(<"$CREDENTIALS_DIRECTORY/url")" "$suffix") \
        --fail --silent --show-error --output /dev/null \
        --max-time 30 --retry-max-time ${toString giveUpSeconds} --retry-delay 30 --retry-all-errors \
        --data-binary @-
      echo sent
    '';
  };

  reportOn = suffix: outcome: {
    path = [ config.systemd.package ];
    scriptArgs = "%i";
    script = ''
      journalctl --sync
      journalctl --boot --unit "$1" --lines 100 --output cat --no-pager \
        | ${lib.getExe ping} "${suffix}" "$1 ${outcome}"
    '';
    serviceConfig = {
      Type = "oneshot";
      PrivateNetwork = true;
    };
  };
in
{
  imports = [ ../secrets.nix ];

  options.my.alerts.healthchecksIo = {
    enable = lib.mkEnableOption ''
      reporting to a healthchecks.io check, whose ping address is
      `healthchecks/url` in the sops file'';

    units = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nixos-upgrade" ];
      description = "Services whose failure is reported, named without `.service`.";
    };

    heartbeat = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nixos-upgrade" ];
      description = ''
        Services whose success pings the check. Set the check's period to
        how often they run, so it alerts when they stop.
      '';
    };

    ping = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      readOnly = true;
      default = if cfg.enable && hasUrl then lib.getExe ping else null;
      defaultText = lib.literalMD "a command, or null while nothing is reported";
      description = ''
        For other modules: the command that pings the check. `ping ""
        <title>` reports a success and `ping /fail <title>` a failure. The
        end of its stdin, up to 10 kB, is the ping's log.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (!hasUrl) {
        warnings = [
          "my.alerts.healthchecksIo: the sops file has no ${secret}, so nothing is reported."
        ];
      })

      (lib.mkIf hasUrl {
        # Naming a unit below creates it, even if no module defines it.
        assertions = map (name: {
          assertion = config.systemd.services.${name}.serviceConfig ? ExecStart;
          message = "my.alerts.healthchecksIo: there is no service ${name} to report on.";
        }) (cfg.units ++ cfg.heartbeat);

        sops.secrets.${secret} = { };

        systemd.sockets.healthchecks-ping = {
          description = "Pings for healthchecks.io";
          wantedBy = [ "sockets.target" ];
          socketConfig = {
            ListenStream = socket;
            Accept = true;
            SocketMode = "0600";
          };
        };

        systemd.services = lib.mkMerge [
          (lib.genAttrs cfg.units (_: {
            onFailure = [ "healthchecks-fail@%n.service" ];
          }))
          (lib.genAttrs cfg.heartbeat (_: {
            onSuccess = [ "healthchecks-success@%n.service" ];
          }))
          {
            "healthchecks-fail@" = reportOn "/fail" "failed" // {
              description = "Report that %i failed";
            };
            "healthchecks-success@" = reportOn "" "succeeded" // {
              description = "Report that %i succeeded";
            };
            "healthchecks-ping@" = {
              description = "Send a ping to healthchecks.io";
              serviceConfig = sandbox.internetClient // {
                ExecStart = lib.getExe send;
                StandardInput = "socket";
                StandardError = "journal";
                DynamicUser = true;
                LoadCredential = "url:${url}";
              };
            };
          }
        ];
      })
    ]
  );
}
