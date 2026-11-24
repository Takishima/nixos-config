# About the hardening of a VPN server

`rpizh` and `rpius` are reachable from the internet. So `my.vpnServer` turns on
`my.hardened`, which holds them tighter than `homelinux`. This page says what
that covers, and what each server still trusts. The examples are for `rpizh`.

## What is closed

- SSH takes keys only, three tries, and only `my.hardened.sshUsers`.
- fail2ban bans an address for an hour after two failures in 15 minutes, and
  twice as long each time it comes back, up to a week. It never bans the home
  network (`my.hardened.neverBan`, 10.x.x.x here). It does ban VPN clients.
- There is no `sudo`. Root is `su -` from `damien`'s session, with root's own
  password, so a stolen SSH key is not root. It is not a wall either: whoever
  has that session can wait for the password to be typed in it.
- Users, passwords and SSH keys are only what the configuration and the sops
  file say. `~/.ssh/authorized_keys` is not read.
- Nobody is a trusted Nix user, since that is root without a password. Only root
  and `sshUsers` talk to the Nix daemon.
- Root builds from the repository, never from a checkout in a home. Whoever
  could write there would decide what root runs next.
- No client's private key is on the Pi. `wireguard-rpizh add` makes it where you
  run it, and shows it once.
- The firewall drops packets from the wrong interface and logs what it refuses.
  Only root reads the kernel log and kernel addresses. The kernel ignores
  redirects and source routes, loads no other kernel with kexec, and writes no
  core dump of a setuid program.
- sshd has one host key, the Ed25519 one kept in 1Password, so a new card is the
  same host to its clients.
- The board's watchdog resets a Pi that hangs for 30 seconds, or that does not
  get through a reboot in 10 minutes. A kernel panic restarts it, and a unit
  that fails at boot does not hold it at an emergency prompt.
- Wi-Fi is off and its driver is not loaded. `my.raspberryPi.wifi` turns it on.
- The Pi announces `rpizh.local` on the home network, not to VPN clients.
  `my.raspberryPi.mdns = false` turns that off.
- It upgrades itself every morning, and goes back when an upgrade leaves it
  out of reach: see [About the automatic upgrades](automatic-upgrades.md).

## What the build refuses

A host that would break one of these does not build. `my.hardened` asserts that
somebody in `sshUsers` has a key, that every user and root has a password in the
sops file, and that no Nix user is trusted.

## What the server trusts

A server trusts three things in turn: `main` of this repository, which it
follows, and the caches `dn-personal.cachix.org`, where its kernel comes from,
and `nix-community.cachix.org`. Whoever can push to one of them is root on the
server. For that reason the CI workflow that fills the cache pins its actions by
commit.
