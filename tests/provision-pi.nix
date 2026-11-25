# provision-<host>, with a stand-in image and a stand-in 1Password CLI: what
# the card ends up with, and what is refused before anything is written.
{
  sshKeys,
  pkgs,
  lib,
  ...
}:
let
  # Two partitions, as an SD image: a FAT one and an ext4 root packed full.
  image =
    pkgs.runCommand "fake-sd-image.img.zst"
      {
        nativeBuildInputs = with pkgs; [
          e2fsprogs
          dosfstools
          util-linux
          zstd
        ];
      }
      ''
        mkdir root
        echo marker > root/from-the-image
        truncate -s 16M root.img
        mkfs.ext4 -q -L NIXOS_SD -d root root.img
        resize2fs -M root.img
        truncate -s 8M boot.img
        mkfs.vfat -n FIRMWARE boot.img

        rootSectors=$(( $(stat -c %s root.img) / 512 ))
        truncate -s $(( (2048 + 16384 + rootSectors) * 512 )) card.img
        sfdisk card.img <<EOF
        label: dos
        start=2048, size=16384, type=b
        start=18432, type=83
        EOF
        dd if=boot.img of=card.img bs=512 seek=2048 conv=notrunc
        dd if=root.img of=card.img bs=512 seek=18432 conv=notrunc
        zstd card.img -o $out
      '';

  provisionFor =
    secrets:
    lib.getExe (
      pkgs.callPackage ../pkgs/provision-pi.nix {
        host = "testpi";
        inherit image secrets;
      }
    )
    + " --yes";
  provision = provisionFor ./fixtures/secrets.yaml;
  forAnotherKey = pkgs.writeText "secrets.yaml" "recipient: age1someoneelse";

  op = pkgs.writeShellScriptBin "op" ''
    case $2 in
      "op://vault/host/private_key?ssh-format=openssh") cat ${sshKeys.snakeOilEd25519PrivateKey} ;;
      *) exit 1 ;;
    esac
  '';
in
{
  name = "provision-pi";

  nodes.machine = {
    virtualisation.emptyDiskImages = [ 256 ];
    environment.systemPackages = [ op ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("a key the secrets are not for is refused, the card untouched"):
        machine.fail("${provisionFor forAnotherKey} --fixed-disk /dev/vdb op://vault/host")
        machine.fail("blkid /dev/vdb")

    with subtest("a disk that is not removable is refused"):
        machine.fail("${provision} /dev/vdb op://vault/host")
        machine.fail("blkid /dev/vdb")

    with subtest("an item without a key is refused"):
        machine.fail("${provision} --fixed-disk /dev/vdb op://vault/nope")
        machine.fail("blkid /dev/vdb")

    with subtest("the card gets the image and the key"):
        machine.succeed("${provision} --fixed-disk /dev/vdb op://vault/host")
        machine.succeed("mkdir /mnt && mount /dev/vdb2 /mnt")
        machine.succeed(
            "test -f /mnt/from-the-image",
            "cmp /mnt/etc/ssh/ssh_host_ed25519_key ${sshKeys.snakeOilEd25519PrivateKey}",
            "test \"$(stat -c '%a %u' /mnt/etc/ssh/ssh_host_ed25519_key)\" = '600 0'",
            "ssh-keygen -y -f /mnt/etc/ssh/ssh_host_ed25519_key | cmp - /mnt/etc/ssh/ssh_host_ed25519_key.pub",
        )

    with subtest("a partition and a mounted card are refused"):
        machine.fail("${provision} --fixed-disk /dev/vdb op://vault/host")
        machine.succeed("umount /mnt && mount /dev/vdb2 /mnt")
        machine.fail("${provision} --fixed-disk /dev/vdb2 op://vault/host")
        machine.succeed("test -f /mnt/from-the-image")

    with subtest("the root fills the card"):
        size = int(machine.succeed("df --output=size -m /mnt | tail -n1"))
        assert size > 200, f"the root is {size} MiB"
        # No copy of the key is left behind.
        machine.fail("ls /dev/shm/tmp.*/key")
  '';
}
