# Search strategy

When you don't know where the documentation for a tool or topic
lives, walk this list top-down. Stop at the first hit.

## Step 1 — Does a man page exist?

```bash
man -w <name> 2>/dev/null && echo found || echo no-man-page
```

`man -w` returns the file path without opening the pager — fast,
non-interactive, and tells you whether the system thinks it knows
anything about `<name>`.

## Step 2 — Search by keyword

```bash
man -k <keyword>            # search descriptions
apropos <keyword>           # alias for the same thing
```

`man -k` is the answer to "I don't remember the tool name, but it
does ${thing}". It scans the one-line `NAME` section of every man
page on the system.

If `man -k` says "nothing appropriate", the whatis database is
stale:

```bash
sudo mandb                  # Linux — rebuild apropos database
```

## Step 3 — Locate the binary and check siblings

```bash
which <tool>
type -a <tool>
command -v <tool>
```

Once you know where the binary lives:

```bash
binary=$(which <tool>)
prefix=$(dirname "$binary")/..
ls "$prefix/share/man/"        # bundled man pages
ls "$prefix/share/doc/"        # bundled docs
ls "$prefix/share/info/"       # bundled info
```

This works for system-installed, Nix-installed, and `./configure --prefix=…`-installed tools.

## Step 4 — Use inline help only if trusted

```bash
# Verify resolution.
type -a <tool>

# Only if the command resolves to a trusted system binary.
<tool> --help 2>&1 | head -n 20
```

See [inline-help.md](inline-help.md) for the full trust checklist.

## Step 5 — Check if it's a builtin

```bash
type <cmd>
```

If the output is "is a shell builtin":

```bash
help <builtin>              # bash
man zshbuiltins             # zsh
```

## Step 6 — Check bundled docs

```bash
ls /usr/share/doc/ | grep -i <name>
```

If a hit:

```bash
ls /usr/share/doc/<name>/
less /usr/share/doc/<name>/README
ls /usr/share/doc/<name>/examples/   # often the most useful
```

## Step 7 — Platform-specific sources

- **Nix-managed systems**: [nix-managed.md](nix-managed.md) for the
  multi-tier `MANPATH`, `nix repl :doc`, and configuration-reference
  man pages.
- **Language-specific docs** (`godoc`, `rustdoc`, `pydoc`,
  `perldoc`): handled by the respective language skills.

## Step 8 — Fall back to the web

Only when steps 1–7 produced nothing, and only after asking yourself:

- Is this maybe a custom tool / script that the user can describe
  directly?
- Does the user's installed version match what the web search will
  return?

## Reading large reference pages efficiently

Configuration reference man pages (`man 5 nix.conf`, `man 5 sshd_config`, `configuration.nix`) can be thousands of lines. Don't
read whole; extract:

```bash
# Grep for a specific option.
man 5 sshd_config | col -bx | grep -A 10 'PermitRootLogin'

# Inside the pager.
man 5 sshd_config
# then type: /PermitRootLogin<Enter>
```

The `col -bx` filter strips backspace-based formatting so `grep`
matches reliably; without it, half the words have non-printable
overstrikes mixed in.
