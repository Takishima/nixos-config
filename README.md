# nixos-config

NixOS and home-manager for three machines, in one flake:

- `homelinux`: Ryzen 7 3700X, Radeon RX 5700, niri with Noctalia on Wayland.
- `rpizh`: Raspberry Pi 4, headless.
- `rpius`: Raspberry Pi 4, headless.

Home-manager runs as a NixOS module, so one switch updates system and home.

## Layout

| Path | Holds |
| --- | --- |
| `flake.nix` | Inputs, the systems, exported modules and overlays |
| `default.nix` | The same outputs without flakes |
| `hosts/<host>/` | One machine: disk, hardware, which features are on. The flake takes every directory here |
| `modules/nixos/` | One module per system feature, each behind a `my.*` option |
| `modules/home/` | One home-manager module per program or domain, also under `my.*` |
| `profiles/` | What a kind of machine needs: `raspberry-pi`, with `my.argonOne` for the fan of an Argon One case, and `my.trialBoot` to boot without U-Boot, a new kernel once as a trial |
| `home/damien/` | Damien's settings: `base.nix` for all, then `minimal.nix` for a server, or `default.nix` where he works and `homelinux.nix` on top. `server-account.nix` is his account on a server |
| `overlays/`, `pkgs/` | Overlays and the packages they add |
| `docs/` | Longer guides: provisioning a Raspberry Pi, the VPN's clients, how a VPN server is hardened and upgrades itself |
| `skills/` | AI skills, as `<area>/<name>/{meta.nix, body.md, references/}` |
| `.claude/skills/` | The skills an agent uses when working on this repository: pointers into `skills/` |
| `.claude/settings.json`, `.claude/cloud-session.md`, `.claude/hooks/` | What an agent gets only in a Claude Code cloud session: its rules, the flake inputs fetched over git, and the binary caches CI uses |
| `secrets/` | sops files, encrypted for the key in `.sops.yaml` |

A feature with a system part and a home part uses one option name for both
(`my.onePassword`, `my.desktop.niri`). The home part follows the system.

| System (`modules/nixos`) | |
| --- | --- |
| `users` | Passwords of the `users.users` from sops, home-manager setup |
| `my.secrets` | sops-nix, decrypting with an SSH key; the file is `secrets/<hostname>.yaml` |
| `my.locale` | Time zone, locales, keyboard layout |
| `my.nix.workstation` | Nix settings sized for a machine one develops on |
| `my.nix.cacheProxy` | ncro in front of cache.nixos.org and the cachix caches |
| `my.nix.nixbuild` | nixbuild.net as remote builder |
| `my.desktop.niri` | niri, greetd, polkit agent, fonts |
| `my.audio`, `my.bluetooth`, `my.logitech` | PipeWire, BlueZ, Solaar |
| `my.printing` | CUPS, and the print queues in `my.printing.printers` |
| `my.fanControl` | CoolerControl, and the out-of-tree `it87` sensor driver |
| `my.smartcard` | PC/SC for the ACR1252 reader, YubiKey tools |
| `my.sshServer` | OpenSSH, key-only |
| `my.fonts` | The desktop font set and extra fonts |
| `my.onePassword` | 1Password GUI and CLI |
| `my.virtualisation` | Docker, libvirt |
| `my.duckdns` | DuckDNS updates, token and names from sops |
| `my.wifi` | NetworkManager Wi-Fi profiles, passwords from sops |
| `my.wireguard` | A WireGuard server: port, subnet and clients declared, keys from sops |
| `my.homebridge` | Homebridge: a HomeKit bridge with the plugins of `my.homebridge.plugins`, and its web interface on port 8581, for every network but the VPN's clients, without privileges |
| `my.hardened` | For a server on the internet: no sudo, root's password from sops, fail2ban, stricter kernel and firewall |
| `my.postSwitch` | The checks a system has to pass after a switch or an upgrade. Each module adds those of what it turns on; a failure is reported |
| `my.autoRollback` | For a server: goes back to the system before when `my.postSwitch.checks` fail, also after a reboot |
| `my.autoUpgrade` | Daily upgrade to this flake's system, judged by `my.postSwitch.checks` |
| `my.alerts.healthchecksIo` | Pings a healthchecks.io check when a unit succeeds, and reports one that fails |
| `my.vpnServer` | `my.wireguard`, `my.hardened`, `my.autoUpgrade`, `my.autoRollback`, `my.alerts.healthchecksIo`, `my.sshServer`, `my.duckdns` and `my.nix.nixbuild`: what a VPN server is made of |

| Home (`modules/home`) | |
| --- | --- |
| `my.shell`, `my.terminal` | fish, bash, starship, direnv, CLI tools; kitty |
| `my.git`, `my.ssh`, `my.onePassword` | git with SSH signing, SSH client, 1Password agent |
| `my.emacs` | Emacs from `github:takishima/emacs-config`, as a daemon |
| `my.development` | Tools by category: `core`, `nix`, `languages`, `cloud` |
| `my.claudeCode`, `my.aiSkills` | Claude Code and its skills |
| `my.spelling` | aspell and hunspell dictionaries |
| `my.cloudSync` | OneDrive with its accounts, Synology Drive, rclone |
| `my.desktop.niri`, `my.desktop.noctalia` | Session, key bindings, bar and lock screen |

`my.aiSkills` renders the skill trees in `skills/` into `~/.claude/skills`.

## Reuse from another flake

Each module is exported under the name of its file or directory, and all of
them as `default`. A module brings everything it needs: no other imports, no
`specialArgs`.

```nix
{
  inputs.nixos-config.url = "github:takishima/nixos-config";

  outputs = { nixpkgs, nixos-config, ... }: {
    nixosConfigurations.other = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-config.nixosModules.audio
        nixos-config.nixosModules.nix-cache-proxy
        {
          my.audio.enable = true;
          my.nix.cacheProxy.enable = true;
        }
      ];
    };
  };
}
```

| Output | |
| --- | --- |
| `nixosModules.<name>`, `nixosModules.default` | The files of `modules/nixos` |
| `homeModules.<name>`, `homeModules.default` | The files of `modules/home` |
| `nixosModules.raspberry-pi-4`, `nixosModules.raspberry-pi-5` | `profiles/raspberry-pi` with nixos-hardware's board module; not part of `default` |
| `packages.<system>.wireguard-<host>` | Manages the clients of a host with `my.wireguard` |
| `packages.<system>.provision-<host>` | Writes a Pi's SD card, with its host key |
| `packages.aarch64-linux.<host>-sd-image` | A Pi's SD image |
| `packages.<system>.sops-host`, `packages.<system>.ncro`, `packages.<system>.homebridge-miot`, `packages.<system>.homebridge-synology` | The packages of the overlays below |
| `packages.<system>.homebridge-password-hash` | Hashes a password for `homebridge/password_hash` |
| `checks.<system>.toplevel-<host>` | Builds a host's system, under the host's own `<system>` |
| `checks.x86_64-linux.formatting`, `checks.x86_64-linux.statix` | `nix fmt` changes nothing; statix finds nothing |
| `checks.x86_64-linux.vm-<name>` | Runs the VM test `tests/<name>.nix` |
| `overlays.packages` | `sops-host` |
| `overlays.homebridge` | The Homebridge plugins `homebridge-miot` and `homebridge-synology`, for `my.homebridge.plugins`, and `homebridge-password-hash` |
| `overlays.ncro` | `ncro`, built against your nixpkgs |
| `overlays.claude-code` | `claude-code` from llm-agents.nix, replacing nixpkgs' |
| `overlays.default` | All of the above |

- Users are the NixOS and home-manager options, `users.users.<name>` and
  `home-manager.users.<name>`.
- A module that grants users something takes their names:
  `my.virtualisation.docker.users`, `my.virtualisation.libvirt.users`,
  `my.logitech.users`, `my.onePassword.users`.
- The NixOS modules apply `overlays.default` themselves.
- With standalone home-manager, add `overlays.default` to your `pkgs`.
  `my.onePassword` and `my.desktop.niri` are off unless you set them.

Without flakes, `default.nix` gives the same outputs:

```nix
let
  nixos-config = import (builtins.fetchGit "https://github.com/takishima/nixos-config");
in
{
  imports = [ nixos-config.nixosModules.audio ];
  nixpkgs.overlays = [ nixos-config.overlays.ncro ];
}
```

```sh
nix-build -A nixosConfigurations.homelinux.config.system.build.toplevel
sudo nixos-rebuild switch --file . --attr nixosConfigurations.homelinux
```

## Secrets

sops-nix decrypts with the SSH host key (`my.secrets.sshKeyPath`).
`.sops.yaml` lists its public half, converted with `ssh-to-age`. The install
below copies the key from Manjaro, so existing secrets still decrypt.

`sops-host` runs sops with that key. It asks for sudo to read it:

```sh
nix run .#sops-host -- secrets/homelinux.yaml   # afterwards just: sops-host secrets/homelinux.yaml
git add secrets/homelinux.yaml
```

The system builds without the file. Each key turns its feature on:

| Key | Effect | Without it |
| --- | --- | --- |
| `password_hash/<user>` | Login password of the normal user `<user>`, from `mkpasswd -m yescrypt` | The password is `changeme`; a `my.hardened` host does not build |
| `password_hash/root` | Root's password on a `my.hardened` host, the only way to root there | That host does not build |
| `wifi/<name>` | Password of the network `my.wifi.networks.<name>` | No profile for that network |
| `duckdns/token`, `duckdns/domains` | DuckDNS account token; its names, one per line | No DuckDNS updates |
| `homebridge/password_hash` | Password of `admin`, the only user of Homebridge's web interface, hashed by `nix run .#homebridge-password-hash` | Whoever opens the web interface first sets the administrator |
| `homebridge/pin` | Code to pair Homebridge's bridge with in Apple Home, as `NNN-NN-NNN` | Homebridge's public code, `031-45-154` |
| `healthchecks/url` | Ping URL of the host's healthchecks.io check | Nothing is reported |
| `wireguard/private_key` | The VPN server's private key | The VPN is not started |
| `wireguard/psk/<client>` | Preshared key of the client `<client>` | The host does not build while that client is enabled |
| `wireguard/endpoint` | Public name clients connect to, for `wireguard-<host> add` | `add` needs `--endpoint` |
| `netrc` | Credentials for private caches, at `/etc/nix/netrc` | Public caches only |
| `nixbuild_ssh_key` | Private key of the nixbuild.net account | No remote builds |

A `/` is a nested key in the file:

```yaml
password_hash:
    alice: $y$j9T$...
```

## Install

`hosts/homelinux/disko.nix` wipes one disk and creates an ESP and a btrfs
partition with the subvolumes `@root`, `@home`, `@nix`, `@log` and
`@snapshots`. The default disk is the SanDisk NVMe, `nvme1n1`. The other NVMe
(Windows, Manjaro, the old `/home`) is not touched; the old `/home` is mounted
read-only at `/mnt/manjaro-home`.

**The default disk holds Manjaro's `/nix`**, and Nix cannot wipe the disk it
runs from. So either:

- install from Manjaro onto another disk, named with `--disk main`, or
- boot the NixOS installer from USB, clone this repository and run the same
  command. First copy `/etc/ssh/ssh_host_ed25519_key` from the Manjaro root
  (`nvme0n1p6`), for `--extra-files`.

```sh
sudo nix run github:nix-community/disko/latest#disko-install -- \
  --flake .#homelinux \
  --disk main /dev/disk/by-id/<disk> \
  --extra-files /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key \
  --write-efi-boot-entries
```

Afterwards:

- Set `device` in `disko.nix` to the disk you used, and commit.
- Pick the system in the firmware boot menu. The new disk has its own ESP with
  systemd-boot; Windows and Manjaro keep theirs.
- Clone this repository to `~/code/nix/nixos-config`, where `nh` expects it,
  and the Emacs configuration to `~/code/emacs/emacs-config`.

## Raspberry Pi

`rpizh` and `rpius` are headless, with the minimal home: shell, git and SSH.
Each is a VPN server (`my.vpnServer`): WireGuard, reachable from the internet
and hardened for it, upgrading itself from this repository every day. `rpizh`
also runs Homebridge, at `http://<its address>:8581` from the home network,
with the plugins for a Dreame vacuum and a Synology NAS.

| To | Read |
| --- | --- |
| Put NixOS on a Pi, update it, recover one that does not boot, or add another | [docs/raspberry-pi.md](docs/raspberry-pi.md) |
| Add, list, shut out or remove a VPN client, or give the server new keys | [docs/vpn-clients.md](docs/vpn-clients.md) |
| Know how a VPN server is hardened, and what it trusts | [docs/server-hardening.md](docs/server-hardening.md) |
| Know when a server rolls an upgrade back, and what its alerts mean | [docs/automatic-upgrades.md](docs/automatic-upgrades.md) |

The commands for `rpizh`; `rpius` has the same under its name:

```sh
nix run .#provision-rpizh -- /dev/<card> "op://<vault>/<item>"     # write a card, with its host key
nix run .#wireguard-rpizh -- add <client>                          # a new VPN client; needs SOPS_AGE_KEY
wg-peers                                                           # the VPN's clients by name, on the Pi, as root
nixos-rebuild switch --refresh --flake github:takishima/nixos-config/rpi#rpizh   # update at once, on the Pi, as root
```

## Update

```sh
nh os switch          # build, show the package diff, activate
nix flake update      # move every input; name one to move only that
nix flake check       # build the system, lint, check formatting, run the VM tests
                      # (CI runs all of it on main, and on a pull request only the checks it changes)
nix fmt               # format with treefmt (nixfmt), see treefmt.nix
```

The VM tests in `tests/` boot the modules in QEMU; each is a check of its own:

```sh
nix build .#checks.x86_64-linux.vm-secrets -L                   # run one
nix run .#checks.x86_64-linux.vm-secrets.driverInteractive      # poke at its VMs
```
