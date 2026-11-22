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
  withPassword = lib.filter (name: has (secret name)) normalUsers;
  sopsSecrets = config.sops.secrets;
in
{
  imports = [ ./secrets.nix ];

  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        let
          hasPassword = has (secret name);
        in
        {
          hashedPasswordFile = lib.mkIf (config.isNormalUser && hasPassword) sopsSecrets.${secret name}.path;
          initialPassword = lib.mkIf (config.isNormalUser && !hasPassword) "changeme";
        }
      )
    );
  };

  config = {
    sops.secrets = lib.genAttrs (map secret withPassword) (_: {
      neededForUsers = true;
    });

    warnings = map (name: ''
      No ${secret name} in the sops file: ${name} gets the initial password
      "changeme". See README.md, "Secrets".
    '') (lib.subtractLists withPassword normalUsers);

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      sharedModules = [ { home.stateVersion = lib.mkDefault config.system.stateVersion; } ];
    };
  };
}
