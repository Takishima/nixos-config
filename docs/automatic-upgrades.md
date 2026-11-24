# About the automatic upgrades

`rpizh` and `rpius` upgrade themselves every morning, with nobody near them.
This page says how they tell a bad upgrade from a good one, what they do about
it, and where that stops. For the hours and the commands, see
[Updates](raspberry-pi.md#updates).

## What a good upgrade is

An upgrade is good when you can still log in, and the server can still fetch the
next upgrade. Whatever else it breaks, a commit to `main` can then repair. So
the checks of a VPN server (`my.autoUpgrade.checks`) are these:

| Check | Passes when |
| --- | --- |
| `sshd` | sshd runs |
| `root-password` | root has a password, which it loses when the sops file is not decrypted |
| `upgrade-timer` | The next upgrade is scheduled |
| `route`, `repository` | There is a route out, and GitHub serves this repository |
| `wireguard` | The VPN runs |

A check that already failed before the upgrade does not count against it: the
upgrade may be what repairs it.

## What the server does with a bad one

The server tries the checks for ten minutes, which leaves a slow network the
time to come up. Then it goes back to the system it ran before.

- After an upgrade that switched the running system, it switches back, and tries
  the upgrade again the next day.
- After an upgrade that rebooted for a new kernel, it reboots into the system
  before. It does the same when the new system boots three times without ever
  passing, which is what a system that hangs after a while looks like.

One failure after a reboot may be a network outage, so the server tries that
upgrade again the next day. After a second failure in a row it leaves the
upgrade alone for a week, or until `main` gives a different system. Otherwise a
bad kernel would reboot the server twice every morning.

## What the checks do not catch

- A kernel that fails before any service starts. The watchdog resets the Pi,
  which boots the same kernel again. Take the card out, or connect a screen and
  choose an older generation in U-Boot's menu.
- The firmware partition, with U-Boot and `config.txt`. Every switch rewrites
  it, and it is not kept per generation: a rollback does not bring the old one
  back.
- A commit that removes the checks. The upgraded system brings its own checks,
  so it is judged by what it says itself.
- A broken `main`. The servers follow it whether CI passed or not.
