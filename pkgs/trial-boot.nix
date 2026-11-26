# Has the Raspberry Pi's firmware start NixOS itself, without U-Boot. A system
# that changes what the firmware loads boots once as a trial, by its tryboot.
{
  writeShellApplication,
  coreutils,
  gnugrep,
  util-linux,

  # config.txt without the lines that say what to boot.
  configTxt,
  # Has share/raspberrypi/boot: the GPU's boot code, device trees and overlays.
  firmware,
  # Where the firmware partition is mounted.
  partition,
  # The vcmailbox of libraspberrypi, which talks to the firmware.
  vcmailbox,
}:
writeShellApplication {
  name = "trial-boot";
  runtimeInputs = [
    coreutils
    gnugrep
    util-linux
  ];
  text = ''
    shopt -s nullglob

    vendorBoot=${firmware}/share/raspberrypi/boot
    # Tells the firmware whether the next reboot reads tryboot.txt: 1 or 0. Not
    # /run/systemd/reboot-param, which a `reboot` without an argument removes.
    tryNextReboot() {
      ${vcmailbox} 0x00038064 4 0 "$1" > /dev/null
    }

    die() {
      echo "trial-boot: $*" >&2
      exit 1
    }

    # Sets what the system $1 boots with: `kernel`, `initrd`, the directory
    # `bootFiles` for them, the file `commandLine`, and `entry`, its config.txt.
    describe() {
      local system=$1 hash
      kernel=$(readlink -f "$system/kernel")
      initrd=$(readlink -f "$system/initrd")
      hash=$(printf '%s\n' "$kernel" "$initrd" "$vendorBoot" | sha256sum)
      bootFiles=nixos/''${hash:0:32}
      hash=$(basename "$system")
      commandLine=cmdline-''${hash:0:32}.txt
      entry=$(
        cat ${configTxt}
        printf '%s\n' "" "[all]" "os_prefix=$bootFiles/" kernel=kernel \
          "initramfs initrd followkernel" "cmdline=$commandLine"
      )
    }

    # Writes under $2 what `describe` named, for the system $1.
    writeBootFiles() {
      local system=$1 directory=$2/$bootFiles
      if [ ! -d "$directory" ]; then
        rm -rf "$directory.tmp"
        mkdir -p "$directory.tmp/overlays"
        cp "$kernel" "$directory.tmp/kernel"
        cp "$initrd" "$directory.tmp/initrd"
        cp "$vendorBoot"/*.dtb "$directory.tmp"
        cp "$vendorBoot"/overlays/* "$directory.tmp/overlays"
        # Without it the firmware takes the overlays from outside os_prefix.
        [ -e "$directory.tmp/overlays/README" ] || die "$vendorBoot/overlays has no README"
        mv "$directory.tmp" "$directory"
      fi
      echo "init=$system/init $(<"$system/kernel-params")" > "$directory/$commandLine"
    }

    # Gives the file $1 the content $2, never leaving it half written.
    replace() {
      printf '%s\n' "$2" > "$1.tmp"
      mv "$1.tmp" "$1"
    }

    # What the entry $1 has the firmware load, whatever system that starts.
    loaded() {
      grep -v '^cmdline=' <<<"$1"
    }

    # Removes from $1 the boot files that neither config.txt nor tryboot.txt names.
    prune() {
      local root=$1 named="" directory file
      for file in "$root"/config.txt "$root"/tryboot.txt; do
        if [ -e "$file" ]; then named+=$(<"$file")$'\n'; fi
      done
      for directory in "$root"/nixos/*/; do
        if ! grep -qxF "os_prefix=nixos/$(basename "$directory")/" <<<"$named"; then
          rm -rf "$directory"
        fi
      done
      for file in "$root"/nixos/*/cmdline-*.txt; do
        if ! grep -qxF "cmdline=$(basename "$file")" <<<"$named"; then
          rm "$file"
        fi
      done
    }

    partition=${partition}
    confirmed=$partition/config.txt
    trial=$partition/tryboot.txt

    onThePartition() {
      mountpoint -q "$partition" || die "$partition is not mounted"
    }

    # Makes the system $1 what the Pi boots: at once if the firmware loads the
    # same files for it as for the confirmed one, else once, as a trial.
    install() {
      local system=$1
      onThePartition
      describe "$system"

      # The partition has room for two sets of boot files.
      if [ -e "$trial" ] && [ "$(<"$trial")" != "$entry" ]; then
        rm "$trial"
        prune "$partition"
      fi
      writeBootFiles "$system" "$partition"

      if [ -e "$confirmed" ] && [ "$(loaded "$(<"$confirmed")")" = "$(loaded "$entry")" ]; then
        if [ "$(<"$confirmed")" != "$entry" ]; then
          replace "$confirmed" "$entry"
        fi
        rm -f "$trial"
        tryNextReboot 0
      else
        replace "$trial" "$entry"
        tryNextReboot 1
        echo "trial-boot: the next reboot tries $system once; any other boot starts the system before"
      fi
      prune "$partition"
      sync -f "$partition"
    }

    # Makes the trial the Pi was booted with what it boots from now on.
    confirm() {
      onThePartition
      [ -e "$trial" ] || return 0
      describe "$(readlink -f /run/booted-system)"
      if [ "$(<"$trial")" != "$entry" ]; then
        echo "trial-boot: a trial is waiting for a reboot, and this boot was not it"
        return 0
      fi
      replace "$confirmed" "$entry"
      rm "$trial"
      prune "$partition"
      sync -f "$partition"
      echo "trial-boot: the Pi now boots $(readlink -f /run/booted-system)"
    }

    # Fills the directory $1, a firmware partition to be, to boot the system $2.
    image() {
      local root=$1 system=$2
      cp "$vendorBoot"/bootcode.bin "$vendorBoot"/start*.elf "$vendorBoot"/fixup*.dat "$root"
      describe "$system"
      writeBootFiles "$system" "$root"
      replace "$root/config.txt" "$entry"
    }

    "$@"
  '';
}
