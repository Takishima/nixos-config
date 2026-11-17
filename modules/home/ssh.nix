{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.ssh;
in
{
  options.my.ssh = {
    enable = lib.mkEnableOption "the SSH client configuration";

    publicKeys = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        github = "ssh-ed25519 AAAA...";
      };
      description = ''
        Public keys whose private half lives in the SSH agent. Each becomes a
        store file, at `my.ssh.identityFiles.<name>`, for IdentityFile to
        select that key in the agent.
      '';
    };

    identityFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Store path of each entry of `publicKeys`.";
    };
  };

  config = lib.mkMerge [
    {
      my.ssh.identityFiles = lib.mapAttrs (
        name: key: toString (pkgs.writeText "${name}.pub" "${key}\n")
      ) cfg.publicKeys;
    }

    (lib.mkIf cfg.enable {
      home.file.".ssh/known_hosts.nix".text = ''
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
      '';

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = [ "~/.ssh/config.local" ];
        settings."*" = {
          UserKnownHostsFile = "~/.ssh/known_hosts ~/.ssh/known_hosts.nix";
          AddKeysToAgent = "yes";
        };
      };
    })
  ];
}
