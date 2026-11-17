# Man pages

The primary documentation system on Unix. Nearly every command,
config file, library function, and system call has a man page.

## Sections

| Section | Contents | Example |
|---|---|---|
| 1 | User commands | `man 1 grep` |
| 2 | System calls | `man 2 open` |
| 3 | Library functions | `man 3 printf` |
| 4 | Device / special files | `man 4 tty` |
| 5 | File formats, config files | `man 5 crontab` |
| 6 | Games | `man 6 fortune` |
| 7 | Miscellaneous (conventions, protocols) | `man 7 signal` |
| 8 | System administration | `man 8 mount` |

When a name exists in multiple sections (`printf` in 1 and 3),
specify it: `man 3 printf`.

## Reading

```bash
man <name>              # search sections in order
man <section> <name>    # specific section
```

Inside the pager (`less`):

- `/pattern` — search forward.
- `?pattern` — search backward.
- `n` — next match.
- `N` — previous match.
- `g` / `G` — jump to start / end.
- `q` — quit.

## Searching

```bash
man -k <keyword>        # search descriptions (same as apropos)
man -f <name>           # one-line description (same as whatis)
man -w <name>           # show file path; reveals which package provides it
```

If `man -k` returns "nothing appropriate", rebuild the whatis
database:

```bash
sudo mandb              # Linux
```

## MANPATH

`man` searches directories listed in `MANPATH`:

```bash
man -w                  # show full search path
manpath                 # alternative (not available everywhere)
```

On Nix-managed systems, `MANPATH` includes per-package store paths —
see [nix-managed.md](nix-managed.md).

## Extracting from large man pages

Some man pages are enormous (`man bash` is ~5000 lines, `man 5 nix.conf` is similar). Extract instead of reading whole:

```bash
# Find a specific option.
man <page> | col -bx | grep -A 15 '<pattern>'

# Extract a named section.
man <page> | col -bx | sed -n '/^ENVIRONMENT/,/^[A-Z]/p'

# Just the synopsis.
man <page> | col -bx | sed -n '/^SYNOPSIS/,/^[A-Z]/p'
```

`col -bx` strips the backspace-based bold/underline formatting that
otherwise breaks pattern matching.

## Section conventions inside a man page

Standard sections, top-to-bottom:

- **NAME** — one-line description.
- **SYNOPSIS** — invocation syntax.
- **DESCRIPTION** — long-form explanation.
- **OPTIONS** — flag reference.
- **EXIT STATUS** — exit-code semantics.
- **ENVIRONMENT** — env vars consulted.
- **FILES** — config files and other paths referenced.
- **EXAMPLES** — concrete invocations (most tools).
- **SEE ALSO** — related man pages.
- **BUGS** — known issues.

When you don't know what you're looking for, jump to `EXAMPLES`
first — fastest path to a working invocation.

## Multi-page references

Some tools fragment their docs across multiple man pages:

| Tool | Pages |
|---|---|
| `git` | `man git`, `man git-<subcommand>` per subcommand |
| `systemd` | `man systemd.<unit-type>`, `man systemd.directives`, etc. |
| `sshd` | `man sshd`, `man 5 sshd_config`, `man 5 ssh_config` |
| `nix` | `man nix.conf` plus `nix --help` for subcommands |

`man -k <tool>` is the fastest way to enumerate every related page.
