{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.secrets;
  exists = cfg.file != null && builtins.pathExists cfg.file;
  text = if exists then builtins.readFile cfg.file else "";
in
{
  options.my.secrets = {
    sshKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/ssh/ssh_host_ed25519_key";
      description = ''
        Ed25519 SSH private key sops-nix decrypts with. Its public half,
        converted with ssh-to-age, is the recipient in .sops.yaml. It has to be
        on the root file system and without a passphrase, since it is read
        during activation.
      '';
    };

    file = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "The host's sops file. It may not exist yet: see `has`.";
    };

    has = lib.mkOption {
      type = lib.types.functionTo lib.types.bool;
      readOnly = true;
      description = ''
        Whether `file` exists and has this top-level key. Modules gate their
        secret on it, so the system builds before any secret is written.
      '';
    };
  };

  config = {
    my.secrets.has = name: lib.hasInfix "\n${name}: " "\n${text}";

    sops = {
      defaultSopsFile = lib.mkIf exists cfg.file;
      age = {
        sshKeyPaths = [ cfg.sshKeyPath ];
        keyFile = null;
        generateKey = false;
      };
      gnupg.sshKeyPaths = [ ];
    };

    environment.systemPackages = [
      pkgs.sops
      pkgs.ssh-to-age
      pkgs.sops-host
    ];
    environment.sessionVariables.SOPS_SSH_KEY = cfg.sshKeyPath;
  };
}
