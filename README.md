# nixos-config

NixOS and home-manager for `homelinux` (Ryzen 7 3700X, Radeon RX 5700), in one
flake. The desktop is niri with Noctalia, on Wayland. Home-manager runs as a
NixOS module, so one switch updates the system and the home.

## Layout

| Path | Holds |
| --- | --- |
| `flake.nix` | Inputs, the `homelinux` system, exported modules and overlays |
| `default.nix` | The same outputs without flakes |
| `hosts/homelinux/` | What is true of this machine: disk, hardware, which features are on |
| `modules/nixos/` | One module per system feature, each behind a `my.*` option |
| `modules/home/` | One home-manager module per program or domain, also under `my.*` |
| `home/damien/` | Damien's values: identity, keys, packages, monitor layout |
| `overlays/`, `pkgs/` | Overlays and the packages they add |
| `skills/` | AI skills, as `<area>/<name>/{meta.nix, body.md, references/}` |
| `secrets/` | sops files, encrypted for the key in `.sops.yaml` |

A feature that has a system half and a home half uses the same option name in
both, and the home half follows the system by default: `my.onePassword`,
`my.desktop.niri`.

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

Every module is exported on its own, named after its file, and all of them as
`default`. Each brings the modules, external modules and overlay it needs, so
nothing else has to be imported and no `specialArgs` are involved:

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

A module that needs the user (`virtualisation`, `onepassword`, `nix`, ...)
pulls in `my.user`, which requires `my.user.name`. The NixOS modules apply
`overlays.default` themselves. With standalone home-manager, add it to the
`pkgs` you pass; `my.onePassword` and `my.desktop.niri` are then off until set.

Without flakes, `default.nix` gives the same outputs, pinned by `flake.lock`:

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

sops-nix decrypts with the SSH host key, `/etc/ssh/ssh_host_ed25519_key`
(`my.secrets.sshKeyPath`). The recipient in `.sops.yaml` is that key's public
half, converted with `ssh-to-age`. The install below carries the key over from
Manjaro, so files encrypted today decrypt on the new system.

`sops-host` is sops with that key as identity; it asks for sudo to read it:

```sh
nix run .#sops-host -- secrets/homelinux.yaml   # afterwards just: sops-host secrets/homelinux.yaml
git add secrets/homelinux.yaml
```

The system builds without the file. Each key turns its feature on:

| Key | Effect | Without it |
| --- | --- | --- |
| `password_hash/<user>` | Login password of `<user>`, from `mkpasswd -m yescrypt` | The password is `changeme` |
| `wifi/<name>` | Password of the network `my.wifi.networks.<name>` | No profile for that network |
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
`@snapshots`. Its default is the SanDisk NVMe, `nvme1n1`. The other NVMe, with
Windows, Manjaro and the old `/home`, is not touched; the old `/home` appears
at `/mnt/manjaro-home`, read-only.

**That default disk holds Manjaro's `/nix`.** Nix cannot wipe the disk it runs
from, so either:

- install from Manjaro onto another disk, naming it with `--disk main`, or
- boot the NixOS installer from USB, clone this repository and run the same
  command there. Copy `/etc/ssh/ssh_host_ed25519_key` from the Manjaro root
  (`nvme0n1p6`) first, for `--extra-files`.

```sh
sudo nix run github:nix-community/disko/latest#disko-install -- \
  --flake .#homelinux \
  --disk main /dev/disk/by-id/<disk> \
  --extra-files /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key \
  --write-efi-boot-entries
```

Then set `device` in `disko.nix` to the disk you used, and commit.

The new disk has its own ESP with systemd-boot. Windows and Manjaro stay on
theirs; pick between them in the firmware boot menu.

After the first boot, clone this repository to `~/code/nix/nixos-config`, where
`nh` expects it, and the Emacs configuration to `~/code/emacs/emacs-config`.

## Update

```sh
nh os switch          # build, show the package diff, activate
nix flake update      # move every input; name one to move only that
nix flake check       # build the system, lint, check formatting, run the VM tests
nix fmt               # format with treefmt (nixfmt), see treefmt.nix
```

The VM tests in `tests/` boot the modules in QEMU; each is a check of its own:

```sh
nix build .#checks.x86_64-linux.vm-secrets -L                   # run one
nix run .#checks.x86_64-linux.vm-secrets.driverInteractive      # poke at its VMs
```
