# hosts

## What goes in a host

Only what is true of this one machine: its name, hardware, disks, users and
their keys, `system.stateVersion`, and the values of `my.*` options. The same
holds for `home/damien/`: it sets options, and a program's configuration is a
module in `modules/home/`.

- Anything a second machine could use is a module in
  [`modules/`](../modules/AGENTS.md), or `profiles/` when it is about a kind of
  machine. Do not copy a block from one host to another.
- `networking.hostName` equals the directory name. `my.secrets` finds the host's
  sops file by it.
- `system.stateVersion` and `hardware-configuration.nix` do not change after the
  install.
- `wireguard.json` changes through `nix run .#wireguard-<host>`, not by hand. A
  new host starts it as `{"peers": {}}`.

## Take care with

- `homelinux/disko.nix` describes a disk that is wiped on install. Change it
  only when asked.
- A change to `my.hardened`, `my.sshServer`, `my.wireguard` or the firewall
  reaches the Pis the next morning, and can lock the owner out of a machine on
  another continent. Say so in your summary, and check `tests/hardened.nix`,
  `tests/ssh-server.nix` and `tests/wireguard.nix` still cover the change.
- A new way into a server adds its check to `my.postSwitch.checks`.

## A new host

Whatever the machine, three steps are the user's, since they need its SSH host
key: making or saving that key, adding its age recipient to `.sops.yaml`, and
writing `secrets/<host>.yaml`. Name them in your summary.

- A Raspberry Pi: follow [docs/raspberry-pi.md](../docs/raspberry-pi.md),
  "Another Pi".
- Any other machine has no guide yet. Start from the host closest to it, and
  ask how it will be installed before you write its disks and boot loader.
  `homelinux` is installed with disko: README.md, "Install".
