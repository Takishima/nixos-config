{
  config,
  lib,
  pkgs,
  ...
}:
let
  administratorPassword = "homebridge/password_hash";
  hasAdministratorPassword = config.my.secrets.has administratorPassword;
  # The format of homebridge-config-ui-x's AuthService.addUser.
  administrator = ''
    (rtrimstr("\n") | split(":")) as $fields
    | if ($fields | length) != 3 or ($fields | any(. == "")) then
        error("homebridge/password_hash is not <iterations>:<salt>:<hash>")
      end
    | $fields as [$iterations, $salt, $hashedPassword]
    | [{
        id: 1,
        username: "admin",
        name: "Administrator",
        $hashedPassword,
        $salt,
        passwordIterations: ($iterations | tonumber),
        sessionVersion: 0,
        admin: true
      }]
  '';
  pairingPin = "homebridge/pin";
  hasPairingPin = config.my.secrets.has pairingPin;
  # Without a restart command the web interface ends the service, which systemd
  # starts again. The one of nixpkgs is sudo, which NoNewPrivileges refuses.
  restartBySystemd = ''del(.platforms[] | select(.platform == "config") | .restart)'';
  setPairingPin = ''
    .bridge.pin = (
      $pin | rtrimstr("\n")
      | if test("^[0-9]{3}-[0-9]{2}-[0-9]{3}$") then . else error("homebridge/pin is not NNN-NN-NNN") end
    )
  '';
  inherit (config.services.homebridge) pluginPath userStoragePath;
  authFile = "${userStoragePath}/auth.json";
  configFile = "${userStoragePath}/config.json";
  inherit (config.services.homebridge) user;
  jq = lib.getExe pkgs.jq;
  declaredPlugins = "${
    pkgs.symlinkJoin {
      name = "homebridge-plugins";
      paths = config.my.homebridge.plugins;
    }
  }/lib/node_modules";
  inherit (config.services.homebridge) settings uiSettings;
  childBridgePorts = {
    start = 52100;
    end = 52150;
  };
  tcpPorts = lib.concatStringsSep ", " [
    (toString uiSettings.port)
    (toString settings.bridge.port)
    "${toString childBridgePorts.start}-${toString childBridgePorts.end}"
  ];
  mdnsPort = 5353;
  sandbox = import ../../lib/service-sandbox.nix;
in
{
  imports = [ ./secrets.nix ];

  options.my.homebridge = {
    enable = lib.mkEnableOption ''
      Homebridge, which shows devices that do not speak HomeKit in Apple Home.
      Its web interface is on port 8581: configure the plugins there. Its only user is `admin`. The sops file holds the
      hash of its password, `homebridge/password_hash`, as
      `nix run .#homebridge-password-hash` prints it: a user or password set
      in the web interface lasts until the next start. Without the key,
      whoever opens the web interface first sets the administrator. The code
      to pair the bridge with is `homebridge/pin`, as `NNN-NN-NNN`; without
      it, it is Homebridge's public one. Every
      network but the clients of `my.wireguard` reaches it. The web interface
      has no terminal, its sessions end when the service restarts, and the
      service holds no privileges'';

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.homebridge-miot ]";
      description = ''
        All the plugins Homebridge has, as packages with
        `lib/node_modules/<plugin>`. One installed in the web interface lasts
        until the next start. A plugin's settings, such as the account of a
        device, are set in the web interface and kept.
      '';
    };
  };

  config = lib.mkIf config.my.homebridge.enable {
    warnings =
      lib.optional (!hasAdministratorPassword) ''
        my.homebridge: the sops file has no ${administratorPassword}, so whoever
        opens the web interface first sets its administrator.
      ''
      ++ lib.optional (!hasPairingPin) ''
        my.homebridge: the sops file has no ${pairingPin}, so the bridge pairs
        with Homebridge's public code until it is paired.
      '';

    sops.secrets =
      lib.genAttrs
        (
          lib.optional hasAdministratorPassword administratorPassword ++ lib.optional hasPairingPin pairingPin
        )
        (_: {
          restartUnits = [ "homebridge.service" ];
        });

    services.homebridge = {
      enable = true;
      settings.ports = childBridgePorts;
    };

    networking = {
      # extraInputRules takes nftables.
      nftables.enable = true;
      firewall.extraInputRules = ''
        iifname != "wg0" tcp dport { ${tcpPorts} } accept
        iifname != "wg0" udp dport ${toString mdnsPort} accept
      '';
    };

    systemd.services.homebridge = {
      environment.HOMEBRIDGE_CONFIG_UI_TERMINAL = lib.mkForce "0";
      preStart = lib.mkAfter (
        ''
          find ${pluginPath} -mindepth 1 -delete
          if [ -d ${declaredPlugins} ]; then
            ln -s -t ${pluginPath} ${declaredPlugins}/*
          fi
        ''
        + ''
          settings=$(${jq} ${
            if hasPairingPin then
              "--rawfile pin ${
                config.sops.secrets.${pairingPin}.path
              } ${lib.escapeShellArg "${restartBySystemd} | ${setPairingPin}"}"
            else
              lib.escapeShellArg restartBySystemd
          } ${configFile})
          printf %s "$settings" | install -m 600 -o ${user} /dev/stdin ${configFile}
        ''
        + lib.optionalString hasAdministratorPassword ''
          users=$(${jq} --raw-input --slurp ${lib.escapeShellArg administrator} ${
            config.sops.secrets.${administratorPassword}.path
          })
          printf %s "$users" | install -m 600 -o ${user} /dev/stdin ${authFile}
          # A new signing key ends the sessions a password before this one opened.
          rm -f ${userStoragePath}/.uix-secrets
        ''
      );
      serviceConfig = sandbox.isolated // {
        AmbientCapabilities = lib.mkForce "";
        # For ExecStartPre, which is root and hands the state to the user.
        CapabilityBoundingSet = lib.mkForce [
          "CAP_CHOWN"
          "CAP_DAC_OVERRIDE"
          "CAP_FOWNER"
        ];
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        # AF_NETLINK lists the interfaces to announce the bridge on.
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
        RestrictSUIDSGID = true;
        SystemCallFilter = [ "@system-service" ];
        UMask = "0077";
      };
    };
  };
}
