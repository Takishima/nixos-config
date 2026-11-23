{
  config,
  lib,
  ...
}:
let
  hasNetrc = config.my.secrets.has "netrc";
in
{
  imports = [ ./secrets.nix ];

  options.my.nix = {
    netrcFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if hasNetrc then "/etc/nix/netrc" else null;
      description = "Where the `netrc` secret lands, or null while the sops file has none.";
    };

    workstation = lib.mkEnableOption ''
      the settings of a machine one develops on: many parallel downloads,
      build outputs kept for debugging, long logs, and a flake's own
      `nixConfig` accepted without asking. Not for a server'';
  };

  config = {
    nixpkgs.config.allowUnfree = true;

    sops.secrets.netrc = lib.mkIf hasNetrc { path = "/etc/nix/netrc"; };

    nix = {
      channel.enable = false;

      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          "ca-derivations"
        ];
        auto-optimise-store = true;
        fallback = true;
        narinfo-cache-negative-ttl = 60;
        netrc-file = lib.mkIf hasNetrc "/etc/nix/netrc";
      }
      // lib.optionalAttrs config.my.nix.workstation {
        accept-flake-config = true;
        builders-use-substitutes = true;
        keep-going = true;
        keep-outputs = true;
        show-trace = true;
        log-lines = 500;
        http-connections = 0;
        max-substitution-jobs = 36;
        download-buffer-size = 1000000000;
      };
    };

    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 14d";
      };
    };
  };
}
