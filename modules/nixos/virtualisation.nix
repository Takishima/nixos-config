{
  config,
  lib,
  ...
}:
let
  cfg = config.my.virtualisation;
in
{
  imports = [ ./user.nix ];

  options.my.virtualisation = {
    docker.enable = lib.mkEnableOption "Docker";
    libvirt.enable = lib.mkEnableOption "libvirt/KVM with virt-manager";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
      };
      my.user.extraGroups = [ "docker" ];
    })
    (lib.mkIf cfg.libvirt.enable {
      virtualisation.libvirtd.enable = true;
      programs.virt-manager.enable = true;
      my.user.extraGroups = [ "libvirtd" ];
    })
  ];
}
