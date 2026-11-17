{ config, lib, ... }:
let
  cfg = config.my.nix.nixbuild;
  hasKey = config.my.secrets.has "nixbuild_ssh_key";
  keyPath = config.sops.secrets.nixbuild_ssh_key.path;
  url = "ssh://${cfg.host}";
in
{
  imports = [ ./secrets.nix ];

  options.my.nix.nixbuild = {
    enable = lib.mkEnableOption "nixbuild.net remote builds";
    host = lib.mkOption {
      type = lib.types.str;
      default = "eu.nixbuild.net";
    };
    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optional (
      !hasKey
    ) "my.nix.nixbuild is on, but the sops file has no nixbuild_ssh_key: nothing builds remotely.";

    programs.ssh.knownHosts.${cfg.host}.publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";

    sops.secrets.nixbuild_ssh_key = lib.mkIf hasKey { };

    nix = lib.mkIf hasKey {
      distributedBuilds = true;
      buildMachines = [
        {
          hostName = cfg.host;
          inherit (cfg) systems;
          sshUser = "root";
          sshKey = keyPath;
          maxJobs = 100;
          speedFactor = 60;
          supportedFeatures = [
            "big-parallel"
            "benchmark"
            "ca-derivations"
          ];
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
