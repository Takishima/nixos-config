# `--help` and shell builtins

Inline help is quick reference for a flag reminder — not a full
manual. Treat `--help` as code execution, not passive lookup.

## Safety rule

Only run `--help` when **all** of these hold:

1. The command is not a path (`/`, `./`, `../`, `~`, or any path
   separator).
1. `type -a <tool>` resolves to a trusted system location (e.g.
   `/usr/bin`, `/run/current-system/sw/bin`, `/etc/profiles/per-user/`).
1. The command is not a repo-provided executable or script.
1. You have no safer local source (`man`, `info`, builtin `help`,
   `/usr/share/doc`).

The reason: `--help` runs the program. A malicious binary placed at
`./tool` or `~/tool` (perhaps via a tarball you just extracted) can
do anything when invoked, including under `--help`. Even legitimate
tools sometimes have side effects on `--help` (config files
created, lock files acquired).

## Verifying trust

```bash
# What does this command actually resolve to?
type -a <cmd>

# Just the first match.
command -v <cmd>

# Show all PATH hits.
which -a <cmd>
```

If the resolution is anywhere under your workspace (`/home/<you>/...`,
the current directory, `/tmp/`), don't run `--help` — read the
binary's source / strings instead.

## Help-flag conventions

```bash
<tool> --help               # GNU convention
<tool> -h                   # short form (some tools)
<tool> help                 # top-level help with subcommand list
<tool> help <subcommand>    # subcommand-specific (git, docker, nix, cargo)
<tool> <subcommand> --help  # alternative subcommand help
```

Modern subcommand-driven tools (`git`, `cargo`, `kubectl`, `nix`,
`docker`) usually accept both forms — `git help log` and
`git log --help` produce the same output (the former piped through
`man`; the latter usually verbatim help text).

## Shell builtins

Shell builtins (`cd`, `export`, `alias`, `set`, `unset`, `read`,
`bind`, etc.) are not external commands — they have no man page on
some systems.

```bash
help <builtin>              # bash built-in help
man zshbuiltins             # zsh builtins reference
man builtin                 # some systems document them under "builtin"
```

To determine whether a command is a builtin, alias, function, or
external:

```bash
type <cmd>                  # what does this resolve to?
type -a <cmd>               # all matches in resolution order
```

Output examples:

| `type` output | Meaning |
|------------------------------|--------------------------------------|
| `<cmd> is a shell builtin` | Use `help <cmd>`. |
| `<cmd> is /usr/bin/<cmd>` | External; man or `--help`. |
| `<cmd> is aliased to ...` | Alias; look up the underlying tool. |
| `<cmd> is a function` | Shell function; `declare -f <cmd>`. |

## Subcommand help patterns

| Tool | Subcommand help |
|---|---|
| `git` | `git help <sub>` (opens man); `git <sub> --help` (same) |
| `docker` | `docker <sub> --help`; `docker help <sub>` |
| `kubectl` | `kubectl <sub> --help`; `kubectl explain <resource>` (extra) |
| `nix` | `nix <sub> --help`; `man nix3-<sub>` |
| `cargo` | `cargo <sub> --help`; `cargo help <sub>` |
| `gh` | `gh <sub> --help`; `gh help <sub>` |
| `terraform` | `terraform <sub> -help` (single dash!) |

Single-dash long flags (`terraform -help`, `find -name`) are older
convention — the same tool may accept double-dash forms in newer
versions.

## When `--help` output is unreadable

```bash
<tool> --help | less        # page through
<tool> --help 2>&1 | head -n 30   # first screenful (errors caught too)
<tool> --help | col -bx           # strip terminal formatting
```

Some tools (`docker`, `kubectl`) produce help that's wider than 80
columns. Set `COLUMNS=120` before invoking if formatting looks
broken.
