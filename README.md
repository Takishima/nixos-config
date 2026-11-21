# nixos-config

NixOS and home-manager for two machines, in one flake:

- `homelinux`: Ryzen 7 3700X, Radeon RX 5700, niri with Noctalia on Wayland.
- `rpizh`: Raspberry Pi 4, headless.

Home-manager runs as a NixOS module, so one switch updates system and home.

## Layout

| Path | Holds |
| --- | --- |
| `flake.nix` | Inputs, the systems, exported modules and overlays |
| `default.nix` | The same outputs without flakes |
| `hosts/<host>/` | One machine: disk, hardware, which features are on |
| `modules/nixos/` | One module per system feature, each behind a `my.*` option |
| `modules/home/` | One home-manager module per program or domain, also under `my.*` |
| `home/damien/` | Damien's settings: `default.nix` for every machine, plus one file per host |
| `overlays/`, `pkgs/` | Overlays and the packages they add |
| `skills/` | AI skills, as `<area>/<name>/{meta.nix, body.md, references/}` |
| `secrets/` | sops files, encrypted for the key in `.sops.yaml` |

A feature with a system part and a home part uses one option name for both
(`my.onePassword`, `my.desktop.niri`). The home part follows the system.

| System (`modules/nixos`) | |
| --- | --- |
| `my.user` | The user and their home-manager module |
| `my.secrets` | sops-nix, decrypting with an SSH key |
| `my.locale` | Time zone, locales, keyboard layout |
| `my.nix.cacheProxy` | ncro in front of cache.nixos.org and the cachix caches |
| `my.nix.nixbuild` | nixbuild.net as remote builder |
| `my.desktop.niri` | niri, greetd, polkit agent, fonts |
| `my.audio`, `my.bluetooth`, `my.logitech` | PipeWire, BlueZ, Solaar |
| `my.printing` | CUPS, and the print queues in `my.printing.printers` |
| `my.fanControl` | CoolerControl, and the out-of-tree `it87` sensor driver |
| `my.smartcard` | PC/SC for the ACR1252 reader, YubiKey tools |
| `my.sshServer` | OpenSSH, key-only, with the user's authorized keys |
| `my.fonts` | The desktop font set and extra fonts |
| `my.onePassword` | 1Password GUI and CLI |
| `my.virtualisation` | Docker, libvirt |
| `my.wifi` | NetworkManager Wi-Fi profiles, passwords from sops |

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

Each module is exported under its file name, and all of them as `default`.
A module brings everything it needs: no other imports, no `specialArgs`.

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
          my.user.name = "alice";
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
| `overlays.packages` | `sops-host` |
| `overlays.ncro` | `ncro`, built against your nixpkgs |
| `overlays.claude-code` | `claude-code` from llm-agents.nix, replacing nixpkgs' |
| `overlays.default` | All of the above |

- Modules that need the user (`virtualisation`, `onepassword`, `nix`, ...)
  require `my.user.name`.
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
| `password_hash` | Login password, from `mkpasswd -m yescrypt` | The password is `changeme` |
| `wifi/<name>` | Password of the network `my.wifi.networks.<name>` | No profile for that network |
| `netrc` | Credentials for private caches, at `/etc/nix/netrc` | Public caches only |
| `nixbuild_ssh_key` | Private key of the nixbuild.net account | No remote builds |

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

`rpizh` has a small home: the shell, git, Claude Code and a terminal Emacs.
The same file, `home/damien/rpizh.nix`, serves Raspberry Pi OS and NixOS.

Emacs's packages and the NixOS kernel are in no binary cache. Building them
takes hours on the Pi, so build on `homelinux`, which emulates aarch64.

### Under Raspberry Pi OS

Standalone home-manager. Needs Nix and a 64-bit system (`uname -m` prints
`aarch64`).

```sh
nix run home-manager -- switch -b hm-backup --flake .#damien@rpizh   # first time
nh home switch                                                        # afterwards
```

Or build on `homelinux` and copy it over:

```sh
nix build '.#homeConfigurations."damien@rpizh".activationPackage'
nix copy --to ssh://rpizh ./result && ssh rpizh "$(readlink result)/activate"
```

### Under NixOS

Hardware support is nixos-hardware's `raspberry-pi-4`: vendor kernel, firmware
partition, U-Boot. `config.txt` is set under `hardware.raspberry-pi.configtxt`.
Build the SD image and write it to the card:

```sh
nix build .#packages.aarch64-linux.rpizh-sd-image
zstd -dc result/sd-image/*.img.zst | sudo dd of=/dev/<card> bs=4M status=progress
```

The root partition grows to fill the card on first boot. To update later
from `homelinux`:

```sh
nixos-rebuild switch --flake .#rpizh --target-host rpizh --sudo
```

After the first boot:

- Log in over SSH with a key from `hosts/rpizh/default.nix`. The password is
  `changeme` until the secrets file has a `password_hash`.
- For secrets, add the Pi's host key to `.sops.yaml` with a rule for
  `secrets/rpizh.yaml`, then create that file.
- Wi-Fi (`my.wifi.networks`) needs those secrets. Until then, use a cable.

## Update

```sh
nh os switch          # build, show the package diff, activate
nix flake update      # move every input; name one to move only that
nix flake check       # build the system, lint, check formatting
nix fmt               # format with treefmt (nixfmt), see treefmt.nix
```
