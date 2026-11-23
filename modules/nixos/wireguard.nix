{
  config,
  lib,
  ...
}:
let
  cfg = config.my.wireguard;
  inherit (config.my.secrets) has;

  privateKey = "wireguard/private_key";
  psk = name: "wireguard/psk/${name}";
  secretFile = name: config.sops.secrets.${name}.path;

  prefix = lib.removeSuffix ".0/24" cfg.subnet;
  # A client's IPv6 address ends as its IPv4 one does: 10.6.0.7 is <subnet6>::7.
  prefix6 = lib.removeSuffix "/64" cfg.subnet6;
  address6 = address: "${prefix6}${lib.last (lib.splitString "." address)}";
  hasIPv6 = cfg.subnet6 != null;
  peers = lib.filterAttrs (_: peer: peer.enable) cfg.peers;
  withPsk = lib.filter (name: has (psk name)) (lib.attrNames peers);

  duplicates =
    values:
    lib.attrNames (lib.filterAttrs (_: same: lib.length same > 1) (lib.groupBy toString values));
  duplicateAddresses = duplicates (lib.mapAttrsToList (_: peer: peer.address) cfg.peers);
  duplicateKeys = duplicates (lib.mapAttrsToList (_: peer: peer.publicKey) cfg.peers);
  badNames = lib.filter (name: builtins.match "[A-Za-z0-9_.-]+" name == null) (
    lib.attrNames cfg.peers
  );
  # A client's address is the subnet's prefix and a last number from 2 to 254.
  isClientAddress =
    address:
    let
      last = builtins.match "${lib.escapeRegex prefix}\\.([1-9][0-9]{0,2})" address;
    in
    last != null && lib.toInt (lib.head last) >= 2 && lib.toInt (lib.head last) <= 254;
  outside = lib.filterAttrs (_: peer: !isClientAddress peer.address) cfg.peers;
in
{
  imports = [ ./secrets.nix ];

  options.my.wireguard = {
    enable = lib.mkEnableOption ''
      a WireGuard server that routes its clients to the local network and
      the internet. Its private key is `wireguard/private_key` in the sops
      file. Manage clients with `nix run .#wireguard-<host>`'';

    port = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "UDP port the server listens on. Forward it on the router.";
    };

    subnet = lib.mkOption {
      type = lib.types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+\\.0/24";
      example = "10.6.0.0/24";
      description = "The VPN's network, a /24. The server is its first address.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${prefix}.1";
      description = "The server's address in the VPN.";
    };

    subnet6 = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "fd[0-9a-f]{2}(:[0-9a-f]{1,4}){0,3}::/64");
      default = null;
      example = "fd3a:91c4:7e02::/64";
      description = ''
        The VPN's IPv6 network, a /64 of private (unique local) addresses,
        or null for IPv4 only. The server is its `::1` and a client ends as
        its IPv4 address does. Clients reach the internet over IPv6 behind
        the server's own address, if the server has one.
      '';
    };

    clientToClient = lib.mkEnableOption "clients reaching one another through the server";

    peers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            publicKey = lib.mkOption {
              type = lib.types.singleLineStr;
              description = "The client's public key.";
            };
            address = lib.mkOption {
              type = lib.types.str;
              example = "10.6.0.2";
              description = "The client's address, in `subnet`.";
            };
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether the client may connect.";
            };
          };
        }
      );
      default = { };
      description = ''
        The clients, by name. One with a `wireguard/psk/<name>` in the sops
        file has to present that preshared key too.
      '';
    };

    dns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      description = "DNS servers in the configuration `wireguard-<host> add` writes for a new client.";
    };

    allowedIPs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "0.0.0.0/0"
        "::/0"
      ];
      description = ''
        What a new client sends through the VPN, in the configuration
        `wireguard-<host> add` writes; the default is everything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = badNames == [ ];
        message = "my.wireguard.peers: names take letters, digits, `_`, `.` and `-` only: ${toString badNames}";
      }
      {
        assertion = outside == { };
        message = "my.wireguard.peers: not a client address of ${cfg.subnet}: ${toString (lib.attrNames outside)}";
      }
      {
        assertion = duplicateAddresses == [ ] && duplicateKeys == [ ];
        message = "my.wireguard.peers: used by more than one client: ${
          toString (duplicateAddresses ++ duplicateKeys)
        }";
      }
    ];

    warnings = lib.optional (
      !has privateKey
    ) "my.wireguard: the sops file has no ${privateKey}, so the VPN is not started.";

    sops.secrets = lib.mkIf (has privateKey) (
      {
        ${privateKey}.restartUnits = [ "wireguard-wg0.service" ];
      }
      // lib.genAttrs' withPsk (
        name:
        lib.nameValuePair (psk name) {
          restartUnits = [ "wireguard-wg0-peer-${name}.service" ];
        }
      )
    );

    networking = {
      wireguard.interfaces.wg0 = lib.mkIf (has privateKey) {
        ips = [ "${cfg.address}/24" ] ++ lib.optional hasIPv6 "${prefix6}1/64";
        listenPort = cfg.port;
        privateKeyFile = secretFile privateKey;
        peers = lib.mapAttrsToList (name: peer: {
          inherit name;
          inherit (peer) publicKey;
          allowedIPs = [ "${peer.address}/32" ] ++ lib.optional hasIPv6 "${address6 peer.address}/128";
          presharedKeyFile = if lib.elem name withPsk then secretFile (psk name) else null;
        }) peers;
      };

      # Forwarding is filtered, which takes nftables: only what comes from the
      # VPN is forwarded, and the NAT below lets it go anywhere.
      nftables = {
        enable = true;
        # A table of its own, ahead of the firewall's, whose forward chain
        # lets ICMPv6 and all that comes from wg0 through.
        tables.wireguard-clients = lib.mkIf (!cfg.clientToClient) {
          family = "inet";
          content = ''
            chain forward {
              type filter hook forward priority filter - 10; policy accept;
              iifname "wg0" oifname "wg0" drop comment "VPN clients do not reach one another"
            }
          '';
        };
      };
      firewall = {
        allowedUDPPorts = [ cfg.port ];
        filterForward = true;
      };
      nat = {
        enable = true;
        enableIPv6 = hasIPv6;
        internalInterfaces = [ "wg0" ];
      };
    };
  };
}
