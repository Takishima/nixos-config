# Bundled documentation

Packages often ship supplementary docs beyond man pages — examples,
READMEs, change logs, design notes. These live under
`/usr/share/doc/` (or the Nix-store equivalent).

## Standard locations

```text
/usr/share/doc/<package>/             # package-specific docs
/usr/share/doc/<package>/examples/    # config samples, scripts
/usr/share/doc/<package>/README*      # package README
/usr/share/doc/<package>/changelog*   # change history
/usr/share/doc/<package>/NEWS*        # release notes (some packages)
/usr/share/doc/<package>/TODO         # known issues / plans
```

`/usr/share/doc/<pkg>/examples/` is the most useful for "I need to
write a config file but the man page is abstract" cases — most
packages drop a working example there.

## Finding what a package shipped

### Debian / Ubuntu

```bash
dpkg -L <package> | grep -E '(doc|man|info)'
dpkg -L <package> | grep -i example
```

### RHEL / Fedora

```bash
rpm -ql <package> | grep -E '(doc|man|info)'
rpm -qd <package>                 # documentation files only
```

### Arch

```bash
pacman -Qpl <package> | grep -E '(doc|man|info)'
```

### Generic: check relative to the binary

```bash
binary=$(which <tool>)
prefix=$(dirname "$binary")/..
ls "$prefix/share/doc/" 2>/dev/null
ls "$prefix/share/man/" 2>/dev/null
```

This works for tools installed by package managers, Nix, manual
`./configure --prefix=…`, and most other source-built installations.

## Reading bundled docs

```bash
# Most are plain text or markdown.
less /usr/share/doc/<package>/README

# Some are gzipped (`.gz` suffix).
zless /usr/share/doc/<package>/README.gz

# Some are in HTML — convert with elinks or w3m.
w3m -dump /usr/share/doc/<package>/manual.html
```

`zless` / `zcat` / `zgrep` transparently decompress; reach for them
instead of `gunzip`-ing into a temp file.

## Nix-managed systems

Bundled docs live in the store, not under `/usr/share/doc/`. See
[nix-managed.md](nix-managed.md) for the per-package docs layout and
how to query them.

## Common useful bundles

| Package | What's worth reading |
|---|---|
| `bash` | `/usr/share/doc/bash/INTRO`, `examples/` — scripts, init files |
| `coreutils` | `/usr/share/doc/coreutils/NEWS` — feature history |
| `git` | `/usr/share/doc/git-doc/` — tutorial, user manual HTML |
| `systemd` | `/usr/share/doc/systemd/examples/` — unit-file templates |
| `openssh-server` | `/usr/share/doc/openssh-server/sshd_config.example` — annotated config |
| `nginx` | `/usr/share/doc/nginx/examples/` — server block templates |
| `vim` | `/usr/share/doc/vim-doc/usr_*` — user-facing manual chapters |

A quick `find /usr/share/doc/ -type d -maxdepth 1 | sort` is a fine
way to see what's installed; cross-reference with `man -k` to find
the ones with non-trivial supplementary content.

## When bundled docs are missing

Some minimal installs (Alpine, slim Docker images) strip
`/usr/share/doc/` entirely to save space:

- Re-install with `--doc` / `--man` if the package manager allows.
- Pull the upstream `man` package from a fuller distribution.
- For Nix: `nix-env -i <pkg>.doc` (or set `documentation.man.enable = true;` in the system config).
