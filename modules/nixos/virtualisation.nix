{
  config,
  lib,
  ...
}:
let
  cfg = config.my.virtualisation;
  users =
    group:
    lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users in the ${group} group. Membership is equivalent to root.";
    };
in
{
  options.my.virtualisation = {
    docker = {
      enable = lib.mkEnableOption "Docker";
      users = users "docker";
    };
    libvirt = {
      enable = lib.mkEnableOption "libvirt/KVM with virt-manager";
      users = users "libvirtd";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
      };
      users.groups.docker.members = cfg.docker.users;
    })
    (lib.mkIf cfg.libvirt.enable {
      virtualisation.libvirtd.enable = true;
      programs.virt-manager.enable = true;
      users.groups.libvirtd.members = cfg.libvirt.users;
    })
  ];
}
