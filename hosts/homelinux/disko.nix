# Wipes `device`; `disko-install --disk main <device>` overrides it.
{ inputs, ... }:
let
  device = "/dev/disk/by-id/nvme-WDS100T3X0C-00SJG0_200971440913";
  btrfsOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  imports = [ inputs.disko.nixosModules.disko ];

  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "nixos"
            ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = btrfsOpts;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = btrfsOpts;
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsOpts;
              };
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = btrfsOpts;
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = btrfsOpts;
              };
            };
          };
        };
      };
    };
  };

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };
}
