# Provisioning a Raspberry Pi

How to take `rpizh`, a Raspberry Pi 4, from Raspberry Pi OS to NixOS without
losing its identity or its VPN clients. The last section adapts it to another
Pi.

Hardware support is nixos-hardware's `raspberry-pi-4`: vendor kernel, firmware
partition, U-Boot. `config.txt` is set under `hardware.raspberry-pi.configtxt`.
`nixosModules.raspberry-pi-5` is the same for a Pi 5; it evaluates, but no Pi 5
has booted it yet.

## What is kept where

| What | Where |
| --- | --- |
| What every Pi needs | `profiles/raspberry-pi/` |
| What a VPN server is made of | `my.vpnServer`, in `modules/nixos/vpn-server.nix` |
| What this Pi is | `hosts/rpizh/`, with the home `home/damien/minimal.nix` |
| The SSH host key, which also decrypts the secrets | 1Password, then `/etc/ssh` on the card |
| Secrets: passwords, the VPN's keys, DuckDNS, Wi-Fi | `secrets/rpizh.yaml`, encrypted for that host key |
| The VPN's clients: names, public keys, addresses | `hosts/rpizh/wireguard.json` |

Nothing the Pi needs is only on its card: a new card from this repository
and the host key is the same machine.

## 1. Save what the old system holds

On the Pi, under Raspberry Pi OS:

```sh
sudo cat /etc/ssh/ssh_host_ed25519_key          # into 1Password, as an SSH Key item
sudo cat /etc/wireguard/wg0.conf                # the VPN server and its clients, as wg0.conf
sudo cat /etc/duckdns/duck.sh                   # the DuckDNS names and token, for the secrets
```

Take the Ed25519 host key, not the RSA or ECDSA one, and not a key from
`~/.ssh`. Copy `wg0.conf` to the machine with this repository, and delete it
once step 3 is done: it holds the server's private key. A tar of the whole
`/etc/wireguard` does as well.

## 2. Secrets

The secrets file is encrypted for the host key. `.sops.yaml` lists its public
half as an age recipient:

```sh
op read "op://<vault>/<item>/public_key" | ssh-to-age
```

Edit the file from any machine, with the private key read from 1Password:

```sh
SOPS_AGE_KEY=$(op read "op://<vault>/<item>/private_key?ssh-format=openssh" | ssh-to-age -private-key) \
  sops secrets/rpizh.yaml
```

| Key | Holds |
| --- | --- |
| `wireguard/private_key` | The VPN server's private key; without it the VPN is not started |
| `wireguard/psk/<client>` | The preshared key of the client `<client>`, if it has one |
| `wireguard/endpoint` | The public name clients connect to; only `wireguard-rpizh add` reads it |
| `duckdns/token` | The DuckDNS account's token |
| `duckdns/domains` | Its names without `.duckdns.org`, one per line |
| `password_hash/<user>` | Login password of `<user>`, from `mkpasswd -m yescrypt` or the old `/etc/shadow`: required for every user |
| `password_hash/root` | Root's password, the only way to root: required |
| `wifi/<name>` | Password of the network `my.wifi.networks.<name>`, with `my.raspberryPi.wifi` |

Every value must be a string. One that is not makes the Pi reject the whole
file. A `/` is a nested key:

```yaml
password_hash:
    damien: $y$j9T$...
```

To keep a password of the old system, take its hash there:
`sudo getent shadow <user> | cut -d: -f2`.

`wireguard/private_key` and `wireguard/psk` are written by the next step.

## 3. Bring the VPN over

The VPN no longer lives in `/etc/wireguard`. Its port and subnet are options
of `my.wireguard`, its clients are in `hosts/rpizh/wireguard.json`, and its
keys in the secrets. `wireguard-rpizh` reads the old server's `wg0.conf`,
PiVPN's or any other, and writes both, at the root of the repository:

```sh
export SOPS_AGE_KEY=$(op read "op://<vault>/<item>/private_key?ssh-format=openssh" | ssh-to-age -private-key)
nix run .#wireguard-rpizh -- --sops import wg0.conf
git add hosts/rpizh/wireguard.json secrets/rpizh.yaml
```

Every client keeps its key, its preshared key and its address, so none has
to be set up again; one PiVPN had disabled stays disabled (`"enable": false`).
Without `--sops` the keys are printed instead, to paste into `sops
secrets/rpizh.yaml`.

It refuses a server whose address is not the first of `my.wireguard.subnet`,
and says so if the old port is not `my.wireguard.port`: set both in
`hosts/rpizh/default.nix` to what the old server has, since that is what the
clients and the router's port forward expect.

## 4. Build the image

On an x86 machine, Nix has to be allowed to build for aarch64:

- NixOS: `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` (`homelinux`
  has it).
- Elsewhere: install the distribution's static QEMU user emulation, add
  `extra-platforms = aarch64-linux` to `/etc/nix/nix.conf` and restart the Nix
  daemon.

```sh
nix build .#packages.aarch64-linux.rpizh-sd-image
```

The build does not read the secrets; the Pi decrypts them itself.

cache.nixos.org does not have the kernel. CI builds it on an ARM runner, for
pull requests and for `main`, and pushes it to `dn-personal.cachix.org`.
Without it the build compiles for hours. A machine
that does not list that cache can name it:

```sh
nix build .#packages.aarch64-linux.rpizh-sd-image \
  --option extra-substituters https://dn-personal.cachix.org \
  --option extra-trusted-public-keys dn-personal.cachix.org-1:8pB//y1vrWsFfDo9FebVmnMU3mF9t4bDDxaeQPN88RE=
```

## 5. Write the card

One command builds the image, writes it, and puts the host key on the card.
It takes the card and the 1Password item holding the host key:

```sh
nix run .#provision-rpizh -- /dev/<card> "op://<vault>/<item>"
```

It needs the 1Password CLI, signed in, and asks for sudo. Before writing
anything it checks that the card is a whole, unmounted disk and that the key is
the one the secrets are encrypted for, then asks you to type the device name.
The key goes from 1Password to the card without touching the disk.

With the key in place the Pi decrypts its secrets on the first boot, the VPN's
among them, and other machines see the host they already know.

Never put the private key in the configuration or in the image build: it would
land in the Nix store, readable by every user and pushed to the cache.

<details>
<summary>The same by hand</summary>

```sh
zstd -dc result/sd-image/*.img.zst | sudo dd of=/dev/<card> bs=4M status=progress

# Grow the root, which the image packs full, then mount it.
echo ",+" | sudo sfdisk -N 2 /dev/<card>
sudo e2fsck -fp /dev/<card>2; sudo resize2fs /dev/<card>2
sudo mount /dev/<card>2 /mnt
sudo install -d -m 755 /mnt/etc/ssh

op read "op://<vault>/<item>/private_key?ssh-format=openssh" \
  | sudo install -m 600 /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key
op read "op://<vault>/<item>/public_key" \
  | sudo install -m 644 /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key.pub

sudo umount /mnt
```

</details>

## 6. First boot

The root partition grows to fill the card. Log in over SSH with a key from
`users.users` in `hosts/rpizh/default.nix`; passwords are not accepted over SSH. Then check:

```sh
systemctl status wireguard-wg0    # the VPN is up
su -c 'wg show wg0'               # the old clients are there, and connect
```

If the card booted before the key was on it, the Pi made a new host key and
cannot read its secrets: the VPN is down and root has no password, so nobody
can become root. Put the key on the card from another machine, as in step 5,
or write the card again.

The Pi asks DHCP for its address: reserve one for it on the router, as
PiVPN was told at its install.

## 7. Updates

The Pi follows `main` of this repository by itself (`my.autoUpgrade`): every
morning around 06:00 it switches to `github:takishima/nixos-config#rpizh`, and
reboots before 08:00 if the kernel changed. That is midnight on the US east
coast, after the VPN's evening use there; `my.autoUpgrade.dates` and
`rebootWindow` in `hosts/rpizh/default.nix` set it. So a change reaches it by being
merged. The repository has to be public for that: the Pi fetches it without
credentials.

After an upgrade that switched the running system, the Pi checks that sshd
and the VPN run and that it has a route out (`my.autoUpgrade.checks`). If
not, it switches back to the system it ran before and tries again the next
day; `journalctl -u nixos-upgrade` says which check failed. An upgrade that
reboots for a new kernel is not checked.

To switch at once, on the Pi, as root:

```sh
su -
nixos-rebuild switch --refresh --flake github:takishima/nixos-config#rpizh
```

Root builds from the repository, never from a checkout in a home: whoever
could write there would decide what root runs next.

The kernel comes from the CI cache, so little is built.
CI fills it for `main`, so wait for its run before switching by hand.

The boot loader in the Pi's EEPROM is not updated by any of this. Its tool
is not installed: `nix shell nixpkgs#raspberrypi-eeprom -c rpi-eeprom-update`,
as root.

A system built on another machine cannot be pushed to the Pi as it is:
nobody there is a trusted Nix user, so it only takes paths signed by a cache
it knows. See "Security" below.

## Security

The Pi is reachable from the internet, so `my.hardened`, which `my.vpnServer`
turns on, holds it tighter than `homelinux`:

- SSH takes keys only, three tries, and only `my.hardened.sshUsers`. fail2ban bans an
  address for an hour after two failures in 15 minutes, twice as long each
  time it comes back, up to a week. Addresses of the home network
  (`my.hardened.neverBan`, 10.x.x.x here) are never banned; VPN clients are.
- There is no `sudo`. Root is `su -` from `damien`'s session, with root's own
  password: a stolen SSH key is not root. It is not a wall either: whoever
  has that session can wait for the password to be typed in it.
- Users, passwords and SSH keys are only what the configuration and the sops
  file say: `~/.ssh/authorized_keys` is not read.
- Nobody is a trusted Nix user: that is root without a password. Only root
  and `sshUsers` talk to the Nix daemon, and root builds from the repository
  only.
- No client's private key is on the Pi. `wireguard-rpizh add` makes it where
  you run it, and shows it once.
- The firewall drops packets from the wrong interface and logs what it
  refuses. Kernel logs and addresses are root's; redirects and source routes
  are ignored.
- sshd has one host key, the Ed25519 one kept in 1Password, so a new card
  is the same host to its clients.
- The board's watchdog resets a Pi that hangs for 30 seconds, or that does
  not get through a reboot in 10 minutes.
- Wi-Fi is off: the driver is not loaded (`my.raspberryPi.wifi` turns it on).
- `rpizh.local` is announced on the home network, not to VPN clients
  (`my.raspberryPi.mdns = false` turns it off).
- It upgrades itself every morning: step 7.

A host that would break one of these does not build: `my.hardened` asserts
that somebody in `sshUsers` has a key, that every user and root has a
password in the sops file, and that no Nix user is trusted.

What the Pi trusts in turn: this repository's `main`, which it follows, and
the caches `dn-personal.cachix.org`, where its kernel comes from, and
`nix-community.cachix.org`. Whoever can push to one of them is root on the Pi. The CI workflow that fills the cache pins
its actions by commit for that reason.

## VPN

The Pi runs a WireGuard server, `networking.wireguard`, set by `my.wireguard`.
`wireguard-rpizh` keeps its clients, from a checkout of this repository on
any machine, at its root:

```sh
nix run .#wireguard-rpizh -- add phone      # a new client
nix run .#wireguard-rpizh -- list
nix run .#wireguard-rpizh -- remove phone
```

`add` gives the client the next free address, and prints its configuration
and the QR code for the phone app. The endpoint in it is `wireguard/endpoint`
of the sops file, read with `SOPS_AGE_KEY` as in step 3, or `--endpoint
<public name>`. Nothing else keeps the client's private
key: scan it then, or have it written with `-o phone.conf`. A client that
made its own key pair hands in the public one, `--public-key <key>`, and
keeps the other.

Each command changes `hosts/rpizh/wireguard.json`, and with `--sops` the
preshared key in `secrets/rpizh.yaml` (it needs `SOPS_AGE_KEY`, as in step
3); without, it prints what to put there. Commit both. The Pi has the client
after its next switch: step 7.

| What | Where |
| --- | --- |
| Port, subnet | `my.wireguard` in `hosts/rpizh/default.nix` |
| IPv6 for the clients, and whether they reach one another | `my.wireguard.subnet6`, `my.wireguard.clientToClient` |
| DNS and routes written into a new client's configuration | `my.wireguard.dns`, `my.wireguard.allowedIPs` |
| The clients: name, public key, address, `"enable": false` to shut one out | `hosts/rpizh/wireguard.json` |
| The server's private key, the clients' preshared keys | `wireguard/private_key`, `wireguard/psk/<client>` in the sops file |

The server's address is the first of the subnet. Clients reach the home
network and the internet through it, but not one another
(`my.wireguard.clientToClient`), and nothing else is forwarded.

With `my.wireguard.subnet6`, a private `fdxx:…::/64`, the VPN carries IPv6
too: the server is its `::1`, and a client ends as its IPv4 address does
(10.6.0.7 is `<subnet6>::7`). They go out behind the Pi's own IPv6 address,
if its network gives it one. `add` writes both addresses; an older client
gets IPv6 once its `Address` line has the second one, as in
`Address = 10.6.0.7/24, <subnet6>::7/64`.

## Another Pi

A directory in `hosts/` is a machine: the flake finds it, and makes its
system, its check in CI and, for a Pi, its image `<name>-sd-image`, its
`provision-<name>` and its `wireguard-<name>`. For another VPN server:

1. Copy `hosts/rpizh/` to `hosts/<name>/` and change what is its own: the
   host name, who logs in, the home network fail2ban spares, the VPN's port
   and subnet. For a Pi 5, import `nixosModules.raspberry-pi-5`. Give it
   `home/damien/minimal.nix` as home unless you work on it.

   | Option | |
   | --- | --- |
   | `my.vpnServer.enable` | SSH, the hardening above, WireGuard, DuckDNS, daily upgrades |
   | `my.hardened.sshUsers`, `neverBan` | Who logs in; the home network, as shell patterns |
   | `my.wireguard.port`, `subnet` | The VPN |
   | `my.duckdns.enable`, `my.autoUpgrade.enable` | On with the role; `false` turns one off |
   | `my.argonOne.enable` | The fan of an Argon One case |
   | `my.raspberryPi.mdns` | `<name>.local` on its network; on by default |
   | `my.raspberryPi.wifi` | Wi-Fi with NetworkManager; off by default |

2. Make its host key, and keep it in 1Password as an SSH Key item:
   `ssh-keygen -t ed25519 -N "" -f ssh_host_ed25519_key`. Add its public
   half to `.sops.yaml` (`ssh-to-age -i ssh_host_ed25519_key.pub`), with a
   rule for `secrets/<name>.yaml`, anchored like the others.
3. Write `secrets/<name>.yaml` as in step 2: `password_hash/root`, one
   `password_hash/<user>` for each user, `duckdns/token` and
   `duckdns/domains`. The host does not build without the passwords.
4. Give it a VPN: empty `hosts/<name>/wireguard.json` to `{"peers": {}}`,
   then

   ```sh
   nix run .#wireguard-<name> -- --sops init      # a new server, or
   nix run .#wireguard-<name> -- --sops import wg0.conf
   ```

5. Follow steps 4 to 6 with `<name>` for `rpizh`, forward the VPN's port on
   its router, and add clients as under "VPN".
