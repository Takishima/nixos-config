# trial-boot on a FAT partition, with stand-in systems and firmware: which
# system the firmware would start, and when a trial replaces it.
{ pkgs, lib, ... }:
let
  firmware = pkgs.runCommand "fake-raspberrypi-firmware" { } ''
    boot=$out/share/raspberrypi/boot
    mkdir -p $boot/overlays
    touch $boot/bootcode.bin $boot/start4.elf $boot/fixup4.dat $boot/bcm2711-rpi-4-b.dtb
    touch $boot/overlays/README $boot/overlays/vc4-kms-v3d.dtbo
  '';

  trialBoot = lib.getExe (
    pkgs.callPackage ../pkgs/trial-boot.nix {
      inherit firmware;
      configTxt = pkgs.writeText "config.txt" ''
        [all]
        arm_64bit=1
      '';
      partition = "/boot/firmware";
      vcmailbox = pkgs.writeShellScript "fake-vcmailbox" ''
        [ "$1 $2 $3" = "0x00038064 4 0" ] && echo "$4" > /run/tryboot-flag
      '';
    }
  );

  kernelOf = name: pkgs.writeTextDir "Image" "kernel ${name}";
  systemWith =
    name: kernel:
    pkgs.runCommand "nixos-system-${name}" { } ''
      mkdir $out
      ln -s ${kernel}/Image $out/kernel
      ln -s ${pkgs.writeTextDir "initrd" "initrd"}/initrd $out/initrd
      echo "console=tty0" > $out/kernel-params
      touch $out/init
    '';
  first = systemWith "first" (kernelOf "old");
  sameKernel = systemWith "same-kernel" (kernelOf "old");
  newKernel = systemWith "new-kernel" (kernelOf "new");
in
{
  name = "trial-boot";

  nodes.machine = {
    virtualisation.emptyDiskImages = [ 64 ];
    environment.systemPackages = [ pkgs.dosfstools ];
  };

  testScript = ''
    firmware = "/boot/firmware"
    tryboot_flag = "/run/tryboot-flag"

    def install(system):
        machine.succeed(f"${trialBoot} install {system}")

    def boot_as(system):
        """Stands in for a boot of the system, then confirms it as the unit does at boot."""
        machine.succeed(f"echo 0 > {tryboot_flag}; ln -sfn {system} /run/booted-system")
        return machine.succeed("${trialBoot} confirm")

    def started_by(entry):
        """The system the firmware starts with this entry, and the kernel it loads for it."""
        settings = dict(
            line.split("=", 1) for line in machine.succeed(f"cat {firmware}/{entry}").splitlines() if "=" in line
        )
        prefix = f"{firmware}/{settings['os_prefix']}"
        machine.succeed(f"test -e {prefix}initrd -a -e {prefix}bcm2711-rpi-4-b.dtb -a -e {prefix}overlays/README")
        command_line = machine.succeed(f"cat {prefix}{settings['cmdline']}")
        system = command_line.split()[0].removeprefix("init=").removesuffix("/init")
        return system, machine.succeed(f"cat {prefix}{settings['kernel']}")

    def boot_directories():
        return int(machine.succeed(f"ls {firmware}/nixos | wc -l"))

    machine.wait_for_unit("multi-user.target")
    machine.succeed(f"mkdir -p {firmware}")

    with subtest("nothing is written while the partition is not mounted"):
        machine.fail("${trialBoot} install ${first}")
        machine.fail(f"ls {firmware}/*")

    machine.succeed(f"mkfs.vfat /dev/vdb && mount /dev/vdb {firmware}")
    machine.succeed(f"echo kernel=u-boot.bin > {firmware}/config.txt")

    with subtest("the first system is a trial, and U-Boot stays what the Pi boots"):
        install("${first}")
        assert started_by("tryboot.txt") == ("${first}", "kernel old")
        assert machine.succeed(f"cat {firmware}/config.txt") == "kernel=u-boot.bin\n"
        assert machine.succeed(f"cat {tryboot_flag}") == "1\n"

    with subtest("the trial that booted becomes what the Pi boots"):
        said = boot_as("${first}")
        assert "now boots" in said, said
        assert started_by("config.txt") == ("${first}", "kernel old")
        machine.fail(f"test -e {firmware}/tryboot.txt")

    with subtest("a system with the same kernel is booted at once"):
        install("${sameKernel}")
        assert started_by("config.txt") == ("${sameKernel}", "kernel old")
        machine.fail(f"test -e {firmware}/tryboot.txt")
        machine.succeed(f"test $(ls {firmware}/nixos/*/cmdline-*.txt | wc -l) = 1")

    with subtest("a system with another kernel is a trial, beside the confirmed one"):
        install("${newKernel}")
        assert started_by("tryboot.txt") == ("${newKernel}", "kernel new")
        assert started_by("config.txt") == ("${sameKernel}", "kernel old")
        assert machine.succeed(f"cat {tryboot_flag}") == "1\n"
        assert boot_directories() == 2

    with subtest("a boot that was not the trial confirms nothing"):
        said = boot_as("${sameKernel}")
        assert "was not it" in said, said
        assert started_by("config.txt") == ("${sameKernel}", "kernel old")
        assert started_by("tryboot.txt") == ("${newKernel}", "kernel new")

    with subtest("installing the trial again arms the next reboot again"):
        install("${newKernel}")
        assert machine.succeed(f"cat {tryboot_flag}") == "1\n"

    with subtest("going back to the confirmed system drops the trial"):
        install("${sameKernel}")
        machine.fail(f"test -e {firmware}/tryboot.txt")
        assert machine.succeed(f"cat {tryboot_flag}") == "0\n"
        assert started_by("config.txt") == ("${sameKernel}", "kernel old")
        assert boot_directories() == 1

    with subtest("a confirmed trial leaves no files of the system before"):
        install("${newKernel}")
        boot_as("${newKernel}")
        assert started_by("config.txt") == ("${newKernel}", "kernel new")
        assert boot_directories() == 1

    with subtest("an image boots its system at once, and has the GPU's boot code"):
        machine.succeed("mkdir /image && ${trialBoot} image /image ${first}")
        machine.succeed("test -e /image/start4.elf -a -e /image/fixup4.dat -a -e /image/bootcode.bin")
        machine.succeed(f"umount {firmware} && mount --bind /image {firmware}")
        assert started_by("config.txt") == ("${first}", "kernel old")
        machine.fail(f"test -e {firmware}/tryboot.txt")
  '';
}
