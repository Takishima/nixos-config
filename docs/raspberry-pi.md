# How to provision a Raspberry Pi

This guide shows you how to move `rpizh`, a Raspberry Pi 4, from Raspberry Pi OS
to NixOS. At the end the Pi runs the system of this repository, with the SSH
host key and the VPN clients it had before.

## Before you start

You need a machine with Nix and a checkout of this repository, and on it `sops`,
`ssh-to-age` and the 1Password CLI, signed in. `homelinux` has them all.

Run every command of this guide at the root of the checkout, unless the step
names the Pi.

## 1. Save what the old system holds

On the Pi, under Raspberry Pi OS:

```sh
sudo cat /etc/ssh/ssh_host_ed25519_key          # into 1Password, as an SSH Key item
sudo cat /etc/wireguard/wg0.conf                # the VPN server and its clients, as wg0.conf
sudo cat /etc/duckdns/duck.sh                   # the DuckDNS names and token, for the secrets
```

- Take the Ed25519 host key, not the RSA or ECDSA one, and not a key from
  `~/.ssh`.
- Copy `wg0.conf` to the checkout. A tar of the whole `/etc/wireguard` does as
  well. Delete it once step 3 is done: it holds the server's private key.

## 2. Secrets

1. Add the host key's public half to `.sops.yaml`, as an age recipient:

   ```sh
   op read "op://<vault>/<item>/public_key" | ssh-to-age
   ```

2. Give `sops` the private half, read from 1Password. The later steps use it
   too:

   ```sh
   export SOPS_AGE_KEY=$(op read "op://<vault>/<item>/private_key?ssh-format=openssh" | ssh-to-age -private-key)
   ```

3. Write the secrets with `sops secrets/rpizh.yaml`. The table in the
   [README](../README.md#secrets) says what each key holds. A VPN server needs:

   | Key | |
   | --- | --- |
   | `password_hash/root` | Required |
   | `password_hash/<user>` | Required, for every user |
   | `duckdns/token`, `duckdns/domains` | For DuckDNS |
   | `wireguard/endpoint` | For `wireguard-rpizh add` |
   | `healthchecks/url` | To be [told of a failed upgrade](#get-told-when-an-upgrade-fails) |
   | `nixbuild_ssh_key` | To build on nixbuild.net |
   | `wireguard/private_key`, `wireguard/psk/<client>` | Step 3 writes them |

Every value must be a string. One that is not makes the Pi reject the whole
file.

To keep a password of the old system, take its hash there:
`sudo getent shadow <user> | cut -d: -f2`.

## 3. Bring the VPN over

`wireguard-rpizh` reads the old server's `wg0.conf`, PiVPN's or any other. It
writes the clients to `hosts/rpizh/wireguard.json` and the keys to the secrets:

```sh
nix run .#wireguard-rpizh -- import wg0.conf
git add hosts/rpizh/wireguard.json secrets/rpizh.yaml
```

Every client keeps its key, its preshared key and its address, so none has to
be set up again. A client PiVPN had disabled stays disabled
(`"enable": false`).

If the command refuses the server's address or reports another port, set
`my.wireguard.subnet` and `my.wireguard.port` in `hosts/rpizh/default.nix` to
what the old server has. The server's address must be the first of the subnet.
The clients and the router's port forward expect both.

## 4. Build the image

On an x86 machine, first allow Nix to build for aarch64:

- NixOS: `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`. `homelinux` has
  it.
- Elsewhere: install the distribution's static QEMU user emulation, add
  `extra-platforms = aarch64-linux` to `/etc/nix/nix.conf` and restart the Nix
  daemon.

```sh
nix build .#packages.aarch64-linux.rpizh-sd-image
```

cache.nixos.org does not have the Pi's kernel. CI builds it and pushes it to
`dn-personal.cachix.org`. If your machine does not list that cache, name it, or
the build compiles for hours:

```sh
nix build .#packages.aarch64-linux.rpizh-sd-image \
  --option extra-substituters https://dn-personal.cachix.org \
  --option extra-trusted-public-keys dn-personal.cachix.org-1:8pB//y1vrWsFfDo9FebVmnMU3mF9t4bDDxaeQPN88RE=
```

## 5. Write the card

One command builds the image, writes it, and puts the host key on the card. It
takes the card and the 1Password item that holds the host key:

```sh
nix run .#provision-rpizh -- /dev/<card> "op://<vault>/<item>"
```

The command asks for sudo. It refuses a card that is mounted or not removable,
and a key the secrets are not encrypted for. Then it asks you to type the
device name.

Never put the private key in the configuration or in the image build. It would
land in the Nix store, readable by every user and pushed to the cache.

## 6. First boot

1. On the router, reserve the address DHCP gives the Pi.
2. Log in with `ssh damien@<the reserved address>`, using the `termius-rpi` or
   the `homelinux-rpi` key. SSH does not accept passwords.
3. Check the VPN:

   ```sh
   systemctl status wireguard-wg0    # the VPN is up
   su -c 'wg show wg0'               # the old clients are there, and connect
   ```

If the card booted before the key was on it, the Pi made a new host key and
cannot read its secrets. The VPN is down and root has no password, so nobody can
become root. Write the card again.

## Updates

The Pi follows `rpi` of this repository by itself (`my.autoUpgrade`). CI moves
`rpi` to a commit of `main` once its checks pass and the cache has its builds,
so a change reaches the Pi by being merged. Every morning around 06:00 the Pi
switches to `github:takishima/nixos-config/rpi#rpizh`, and reboots before 08:00
if the kernel changed. The hours are in the Pi's own time zone,
`my.locale.timeZone`. To change them for one Pi, set `my.autoUpgrade.dates` and
`rebootWindow` in `hosts/rpizh/default.nix`.

The repository has to stay public: the Pi fetches it without credentials.

If an upgrade fails one of `my.postSwitch.checks`, the Pi goes back to the
system it ran before: see [About the automatic upgrades](automatic-upgrades.md).
To see which check failed, on the Pi:

```sh
journalctl -u nixos-upgrade -u nixos-upgrade-confirm
```

To switch at once, wait for CI's run on `main` to move `rpi`. Then, on the Pi:

```sh
su -
nixos-rebuild switch --refresh --flake github:takishima/nixos-config/rpi#rpizh
```

You cannot push a system built on another machine to the Pi. It only takes
paths signed by a cache it knows: see
[About the hardening of a VPN server](server-hardening.md).

To update the boot loader in the Pi's EEPROM, which an upgrade does not touch,
run as root `nix shell nixpkgs#raspberrypi-eeprom -c rpi-eeprom-update -a`, then
reboot.

### Get told when an upgrade fails

The Pi reports its upgrades to a check on
[healthchecks.io](https://healthchecks.io), which tells you by email when one
fails, or when the Pi goes silent.

1. On healthchecks.io, add a check named `rpizh`, with a period of 1 day and a
   grace time of 3 hours.
2. Put the check's ping URL in the sops file, with `sops secrets/rpizh.yaml`:

   ```yaml
   healthchecks:
       url: https://hc-ping.com/<uuid>
   ```

3. Commit the file to `main`. The Pi reports from its next upgrade on.
4. Try it, on the Pi as root. The first command turns the check red and sends
   you the alert, the second turns it green again:

   ```sh
   systemctl start healthchecks-fail@nixos-upgrade.service
   systemctl start healthchecks-success@nixos-upgrade.service
   ```

## If the Pi does not boot

The watchdog resets a Pi that hangs, which then boots the same system again.
First get the Pi up in one of two ways:

- Connect a screen and a keyboard. U-Boot shows its menu for one second: choose
  an older generation there.
- Write the card again from a commit that booted: check it out and follow
  [step 5](#5-write-the-card). The Pi comes back as the same machine.

Then repair `main` before the next morning. Until you do, the Pi upgrades to
the same system again, and the first way boots it again at any reboot.

The kernel logs to the serial console too, `ttyS0` at 115200 baud.

A card that died is replaced the same way, from `main`.

## Another Pi

The flake makes a machine of every directory in `hosts/`, with its system and
its check in CI. A Pi also gets `<name>-sd-image` and `provision-<name>`, and a
VPN server `wireguard-<name>`. For another VPN server:

1. Copy `hosts/rpizh/` to `hosts/<name>/` and change what is its own:

   | What | Option |
   | --- | --- |
   | The host name | `networking.hostName` |
   | Who logs in | The import of `home/damien/server-account.nix`: Damien, with the keys `termius-rpi` and `homelinux-rpi` of `home/damien/ssh-keys.nix` |
   | The home network, which fail2ban spares | `my.hardened.neverBan` |
   | The VPN's port and subnet | `my.wireguard.port`, `my.wireguard.subnet` |
   | IPv6 and DNS for the VPN's clients | `my.wireguard.subnet6`, `my.wireguard.dns` |
   | The time zone and the locales | `my.locale` |
   | The fan, if the Pi is in an Argon One case | `my.argonOne.enable` |

   Keep the import of `home/damien/server-account.nix` unless you work on the
   machine. For a Pi 5, import `nixosModules.raspberry-pi-5`. It evaluates, but
   no Pi 5 has booted it yet.

   The flake only sees files git tracks: `git add hosts/<name>`.

2. Make its host key in 1Password, so that no file ever holds the private half:

   ```sh
   op item create --category ssh --ssh-generate-key ed25519 --vault <vault> --title <name>
   ```

3. Add the key's public half to `.sops.yaml`, with a rule for
   `secrets/<name>.yaml` anchored like the others:
   `op read "op://<vault>/<name>/public_key" | ssh-to-age`.
4. Write `secrets/<name>.yaml` as in step 2 above, then
   `git add .sops.yaml secrets/<name>.yaml`. The host does not build without
   the passwords.
5. Give it a VPN. The copied `hosts/<name>/wireguard.json` holds `rpizh`'s
   server and clients: replace its content with `{"peers": {}}`, then:

   ```sh
   nix run .#wireguard-<name> -- init      # a new server, or
   nix run .#wireguard-<name> -- import wg0.conf
   ```

6. Follow steps 4 to 6 above with `<name>` for `rpizh`.
7. Forward the VPN's port on its router, and
   [add its clients](vpn-clients.md).
