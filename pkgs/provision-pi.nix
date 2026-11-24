# Writes a Raspberry Pi's SD image to a card and puts on it what the image
# must not hold: the SSH host key, read from 1Password.
{
  lib,
  writeShellApplication,
  coreutils,
  e2fsprogs,
  gnugrep,
  openssh,
  parted,
  ssh-to-age,
  util-linux,
  zstd,

  host,
  # The directory system.build.sdImage makes, or an .img.zst file.
  image,
  # age recipients of the host's sops file: the key has to be one of them.
  recipients ? [ ],
}:
writeShellApplication {
  name = "provision-${host}";
  runtimeInputs = [
    coreutils
    e2fsprogs
    gnugrep
    openssh
    parted
    ssh-to-age
    util-linux
    zstd
  ];
  text = ''
    usage() {
      cat <<EOF
    Usage: provision-${host} [--yes] <card> <1password-item>

      <card>            the SD card, as a whole disk: /dev/sdb, /dev/mmcblk0
      <1password-item>  the SSH Key item holding ${host}'s host key: op://<vault>/<item>

    Everything on the card is erased. Needs the 1Password CLI, signed in.
    EOF
    }

    die() {
      echo "provision-${host}: $*" >&2
      exit 1
    }

    yes=
    if [ "''${1:-}" = --yes ]; then
      yes=1
      shift
    fi
    if [ $# -ne 2 ]; then
      usage
      exit 1
    fi
    card=$1
    item=''${2%/}

    sudo=sudo
    [ "$(id -u)" = 0 ] && sudo=

    image=${image}
    [ -d "$image" ] && image=$(echo "$image"/sd-image/*.img.zst)
    [ -f "$image" ] || die "no image at $image"

    [ -b "$card" ] || die "$card is not a block device"
    [ "$(lsblk -dno TYPE "$card")" = disk ] || die "$card is a partition, not a whole disk"
    if lsblk -no MOUNTPOINTS "$card" | grep -q .; then
      die "$card is in use: unmount it first"
    fi

    command -v op >/dev/null || die "the 1Password CLI, op, is not on PATH"

    # The key is checked before anything is written. It only ever sits in memory.
    umask 077
    work=$(mktemp -d -p "''${XDG_RUNTIME_DIR:-/dev/shm}")
    mnt=$work/mnt
    cleanup() {
      if mountpoint -q "$mnt"; then $sudo umount "$mnt"; fi
      rm -rf "$work"
    }
    trap cleanup EXIT

    op read "$item/private_key?ssh-format=openssh" >"$work/key" ||
      die "cannot read the private key of $item"
    ssh-keygen -y -f "$work/key" >"$work/key.pub" || die "$item does not hold an SSH private key"
    grep -q '^ssh-ed25519 ' "$work/key.pub" || die "the key of $item is not an Ed25519 key"
    ${lib.optionalString (recipients != [ ]) ''
      recipient=$(ssh-to-age <"$work/key.pub")
      recipients=${lib.escapeShellArg (toString recipients)}
      case " $recipients " in
        *" $recipient "*) ;;
        *) die "the key of $item cannot decrypt ${host}'s secrets: it is $recipient" ;;
      esac
    ''}

    echo "About to erase:"
    lsblk -dno NAME,SIZE,TRAN,MODEL "$card"
    if [ -z "$yes" ]; then
      read -r -p "Type $card to go on: " answer </dev/tty
      [ "$answer" = "$card" ] || die "not confirmed"
    fi

    echo "Writing the image..."
    zstd -dc "$image" | $sudo dd of="$card" bs=4M conv=fsync status=progress
    $sudo partprobe "$card"
    $sudo udevadm settle

    root=$(lsblk -lnpo NAME "$card" | sed -n 3p)
    [ -b "$root" ] || die "no second partition on the card"

    # The image's root is packed full. Growing it now, as the Pi would on its
    # first boot, leaves room for the files.
    echo ",+" | $sudo sfdisk --no-reread -N 2 "$card" >/dev/null
    $sudo partprobe "$card"
    $sudo udevadm settle
    $sudo e2fsck -fp "$root" || [ $? -le 2 ]
    $sudo resize2fs "$root"

    mkdir "$mnt"
    $sudo mount "$root" "$mnt"

    echo "Installing the host key..."
    $sudo install -d -m 755 "$mnt/etc" "$mnt/etc/ssh"
    $sudo install -m 600 -o 0 -g 0 "$work/key" "$mnt/etc/ssh/ssh_host_ed25519_key"
    $sudo install -m 644 -o 0 -g 0 "$work/key.pub" "$mnt/etc/ssh/ssh_host_ed25519_key.pub"

    $sudo umount "$mnt"
    sync
    echo "Done. The card is ready for ${host}."
  '';
}
