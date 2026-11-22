{
  config,
  lib,
  ...
}:
let
  cfg = config.my.user;
  inherit (config.my.secrets) has;
  perUser = "password_hash/${cfg.name}";
  # A flat `password_hash` is the layout from before the per-user keys.
  secret = lib.findFirst has null [
    perUser
    "password_hash"
  ];
  hasPassword = secret != null;
in
{
  imports = [ ./secrets.nix ];

  options.my.user = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Login name.";
    };
    fullName = lib.mkOption {
      type = lib.types.str;
      default = cfg.name;
      defaultText = lib.literalExpression "config.my.user.name";
      description = "Name shown by the greeter.";
    };
    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Groups on top of wheel. Modules add the ones their feature needs.";
    };
    home = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "Home-manager module of this user: a path or a module.";
    };
  };

  config = {
    sops.secrets = lib.mkIf hasPassword { ${secret}.neededForUsers = true; };

    users.users.${cfg.name} = {
      isNormalUser = true;
      uid = 1000;
      description = cfg.fullName;
      extraGroups = [ "wheel" ] ++ cfg.extraGroups;
      hashedPasswordFile = lib.mkIf hasPassword config.sops.secrets.${secret}.path;
      initialPassword = lib.mkIf (!hasPassword) "changeme";
    };

    warnings =
      lib.optional (!hasPassword) ''
        No ${perUser} in the sops file: ${cfg.name} gets the initial password
        "changeme". See README.md, "Secrets".
      ''
      ++ lib.optional (hasPassword && secret != perUser) ''
        The sops file has a flat password_hash, used for ${cfg.name}. Move it
        to ${perUser}. See README.md, "Secrets".
      '';

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      users.${cfg.name} = {
        imports = [ cfg.home ];
        home.stateVersion = lib.mkDefault config.system.stateVersion;
      };
    };
  };
}
