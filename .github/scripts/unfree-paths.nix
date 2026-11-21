# Store paths of the unfree packages a NixOS configuration installs, for
# push-cache.sh. Applied with `nix eval --apply` to the configuration's config.
# It only sees packages installed directly: one wrapped in a free package is
# missed, so this is a tripwire and not a filter.
config:
let
  packages =
    config.environment.systemPackages
    ++ builtins.concatMap (user: user.packages) (builtins.attrValues config.users.users)
    ++ builtins.concatMap (home: home.home.packages) (builtins.attrValues config.home-manager.users)
    ++ config.fonts.packages;
  unfree = builtins.filter (p: builtins.isAttrs p && (p.meta.unfree or false)) packages;
in
builtins.concatMap (p: map (output: p.${output}.outPath) (p.outputs or [ "out" ])) unfree
