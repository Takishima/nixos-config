{
  config,
  lib,
  ...
}:
let
  user = config.my.user.name;
  hasNetrc = config.my.secrets.has "netrc";
in
{
  imports = [
    ./secrets.nix
    ./user.nix
  ];

  options.my.nix.netrcFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    readOnly = true;
    default = if hasNetrc then "/etc/nix/netrc" else null;
    description = "Where the `netrc` secret lands, or null while the sops file has none.";
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
        trusted-users = [ user ];
        accept-flake-config = true;
        auto-optimise-store = true;
        builders-use-substitutes = true;
        keep-going = true;
        keep-outputs = true;
        show-trace = true;
        log-lines = 500;
        fallback = true;
        http-connections = 0;
        max-substitution-jobs = 36;
        download-buffer-size = 1000000000;
        narinfo-cache-negative-ttl = 60;
        netrc-file = lib.mkIf hasNetrc "/etc/nix/netrc";
      };
    };

    programs.nh = {
      enable = true;
      flake = "/home/${user}/code/nix/nixos-config";
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 14d";
      };
    };
  };
}
