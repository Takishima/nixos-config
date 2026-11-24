# sops-nix, decrypting the host's sops file with an SSH key.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.secrets;
  ownFile = ../../secrets + "/${config.networking.hostName}.yaml";
  exists = cfg.file != null && builtins.pathExists cfg.file;
  text = if exists then builtins.readFile cfg.file else "";

  valuePaths =
    let
      step =
        acc: line:
        let
          m = builtins.match "( *)([^ #:-][^:]*):( .*)?" line;
          indent = lib.stringLength (lib.elemAt m 0);
          stack = lib.filter (e: e.indent < indent) acc.stack ++ [
            {
              inherit indent;
              key = lib.elemAt m 1;
            }
          ];
        in
        if m == null then
          acc
        else
          {
            inherit stack;
            paths =
              acc.paths ++ lib.optional (lib.elemAt m 2 != null) (lib.concatMapStringsSep "/" (e: e.key) stack);
          };
    in
    (lib.foldl' step {
      stack = [ ];
      paths = [ ];
    } (lib.splitString "\n" text)).paths;
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
      default = if builtins.pathExists ownFile then ownFile else null;
      defaultText = lib.literalMD "`secrets/<hostname>.yaml` of this repository, if there is one";
      description = "The host's sops file. It may not exist yet: see `has`.";
    };

    has = lib.mkOption {
      type = lib.types.functionTo lib.types.bool;
      readOnly = true;
      description = ''
        Whether `file` exists and has a value at this key, nested keys written
        as a sops-nix path (`wifi/home`). Modules gate their secret on it, so
        the system builds before any secret is written.
      '';
    };
  };

  config = {
    my.secrets.has = name: lib.elem name valuePaths;

    sops = {
      defaultSopsFile = lib.mkIf exists cfg.file;
      age.sshKeyPaths = [ cfg.sshKeyPath ];
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
