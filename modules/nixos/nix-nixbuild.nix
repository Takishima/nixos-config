{ config, lib, ... }:
let
  cfg = config.my.nix.nixbuild;
  hasKey = config.my.secrets.has "nixbuild_ssh_key";
  keyPath = config.sops.secrets.nixbuild_ssh_key.path;
  host = "eu.nixbuild.net";
  url = "ssh://${host}";
in
{
  imports = [ ./secrets.nix ];

  options.my.nix.nixbuild = {
    enable = lib.mkEnableOption "nixbuild.net remote builds";
    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
    extraFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "kvm"
        "nixos-test"
      ];
      description = ''
        More build features to use the builder for. A build that needs one
        runs there when this machine cannot do it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optional (
      !hasKey
    ) "my.nix.nixbuild is on, but the sops file has no nixbuild_ssh_key: nothing builds remotely.";

    programs.ssh = {
      knownHosts.${host}.publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
      extraConfig = ''
        Host ${host}
          ServerAliveInterval 60
      ''
      + lib.optionalString hasKey ''
        Match host ${host} localuser root
          IdentityFile ${keyPath}
      '';
    };

    sops.secrets.nixbuild_ssh_key = lib.mkIf hasKey { };

    nix = lib.mkIf hasKey {
      distributedBuilds = true;
      buildMachines = [
        {
          hostName = host;
          inherit (cfg) systems;
          sshUser = "root";
          sshKey = keyPath;
          maxJobs = 100;
          speedFactor = 60;
          supportedFeatures = [
            "big-parallel"
            "benchmark"
            "ca-derivations"
          ]
          ++ cfg.extraFeatures;
        }
      ];
      settings = {
        substituters = [ "${url}?priority=100&ssh-key=${keyPath}" ];
        trusted-substituters = [ url ];
        trusted-public-keys = [ "nixbuild.net/Z6CTD4-1:VBiuum96GizlEloWpAViYlEpN2X75gK66asbO/RZvDM=" ];
      };
    };
  };
}
