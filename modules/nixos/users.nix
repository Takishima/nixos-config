# Users are declared with the NixOS options (`users.users.<name>`,
# `home-manager.users.<name>`). This gives every normal user their password
# from the sops file, and sets home-manager up.
{
  config,
  lib,
  ...
}:
let
  inherit (config.my.secrets) has;
  secret = name: "password_hash/${name}";
  normalUsers = lib.attrNames (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);

  # A flat `password_hash` is the layout from before the per-user keys. It can
  # only be meant for a sole user.
  hasFlat = has "password_hash";
  secretOf =
    name:
    if has (secret name) then
      secret name
    else if hasFlat && normalUsers == [ name ] then
      "password_hash"
    else
      null;

  secrets = lib.filterAttrs (_: key: key != null) (lib.genAttrs normalUsers secretOf);
  withoutPassword = lib.subtractLists (lib.attrNames secrets) normalUsers;
  sopsSecrets = config.sops.secrets;
in
{
  imports = [ ./secrets.nix ];

  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        let
          key = secretOf name;
        in
        {
          hashedPasswordFile = lib.mkIf (config.isNormalUser && key != null) sopsSecrets.${key}.path;
          initialPassword = lib.mkIf (config.isNormalUser && key == null) "changeme";
        }
      )
    );
  };

  config = {
    sops.secrets = lib.mapAttrs' (_: key: lib.nameValuePair key { neededForUsers = true; }) secrets;

    warnings =
      map (name: ''
        No ${secret name} in the sops file: ${name} gets the initial password
        "changeme". See README.md, "Secrets".
      '') withoutPassword
      ++ lib.optional hasFlat ''
        The sops file has a flat password_hash. Move it to password_hash/<user>.
        See README.md, "Secrets".
      '';

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      sharedModules = [ { home.stateVersion = lib.mkDefault config.system.stateVersion; } ];
    };
  };
}
