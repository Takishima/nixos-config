# ncro: a local proxy racing the upstream binary caches.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.nix.cacheProxy;
  inherit (config.my.nix) netrcFile;
in
{
  imports = [ ./nix.nix ];

  options.my.nix.cacheProxy = {
    enable = lib.mkEnableOption "substituting through a local ncro cache proxy";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4200;
    };

    upstreams = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      description = "Caches ncro fronts, as its `upstreams` setting: url, priority, public_key.";
      default = [
        {
          url = "https://cache.nixos.org";
          priority = 10;
          public_key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        }
        {
          url = "https://hx-rh-devel.cachix.org";
          priority = 10;
          public_key = "hx-rh-devel.cachix.org-1:3CQaXpjF25/AVY+vF0ow2JK0fAWyRxEwl8wBbD2DPcE=";
        }
        {
          # Filled by CI (.github/workflows/check.yml).
          url = "https://dn-personal.cachix.org";
          priority = 20;
          public_key = "dn-personal.cachix.org-1:8pB//y1vrWsFfDo9FebVmnMU3mF9t4bDDxaeQPN88RE=";
        }
        {
          url = "https://nix-community.cachix.org";
          priority = 20;
          public_key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
        }
        {
          url = "https://devenv.cachix.org";
          priority = 20;
          public_key = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
        }
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.ncro = {
      enable = true;
      package = pkgs.ncro;
      addUpstreamPublicKeys = true;
      settings = {
        server.listen = "127.0.0.1:${toString cfg.port}";
        logging.timestamps = false;
        cache.negative_ttl = "2m";
        inherit (cfg) upstreams;
      };
    }
    // lib.optionalAttrs (netrcFile != null) { inherit netrcFile; };

    sops.secrets = lib.mkIf (netrcFile != null) { netrc.restartUnits = [ "ncro.service" ]; };

    # cache.nixos.org stays as fallback when the proxy is down.
    nix.settings.substituters = lib.mkBefore [ "http://localhost:${toString cfg.port}?priority=0" ];
  };
}
