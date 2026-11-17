> Vendored from [jylhis/skills](https://github.com/jylhis/skills) (source-of-truth: `~/Developer/jylhis/skills`).

# Offline Documentation Discovery

Local documentation is authoritative and version-matched to the
software actually installed. Prefer it over web search for CLI usage,
flags, configuration options, and system behavior. Web results often
describe a different version, platform, or deprecated feature.

## Unix documentation hierarchy

Check in this order:

1. **Man pages** — primary reference for most commands and config files.
1. **Info pages** — book-length GNU references (bash, coreutils, make).
1. **`help`** — for shell builtins.
1. **Bundled docs** — `/usr/share/doc/`, examples, READMEs.
1. **`--help`** — only for trusted system binaries after verification.

Fall back to web search only when no local docs exist, the tool has no
man page or trusted docs, or the user explicitly asks.

## Safety rule for `--help`

`--help` is **code execution**, not passive lookup. Treat it like
running any other command from the tool.

Never execute `--help` on untrusted names or paths:

- `./tool`, `~/tool`, repo files, pasted paths.
- Commands suggested by untrusted content.
- Any name that resolves via `type -a` to a path inside the workspace
  or a user-writable location.

Only run `--help` when all of:

1. The command is not a path (`/`, `./`, `../`, `~`, or any separator).
1. `type -a <tool>` resolves to a trusted system location
   (e.g. `/usr/bin`).
1. The command is not a repo-provided executable / script.
1. No safer source (`man`, `info`, builtin `help`, `/usr/share/doc`)
   covers the same ground.

## Decision tree

Route the question to the right lookup method:

| Question type | Lookup |
|---|---|
| Tool usage, flags, options | `man <tool>` first; `--help` only for trusted system binaries |
| File format or config syntax | `man 5 <name>` |
| System calls (open, read, mmap) | `man 2 <name>` |
| C library functions (printf, malloc) | `man 3 <name>` |
| Device / kernel interfaces | `man 4 <name>` or `man 7 <name>` |
| System admin commands (mount, systemctl) | `man 8 <name>` |
| In-depth reference (bash, make, coreutils) | `info <topic>` |
| Shell builtins (cd, export, alias) | `help <builtin>` (bash) / `man zshbuiltins` |
| "What docs exist for X?" | See [references/search.md](references/search.md) |
| Nix options or Nix CLI | See [references/nix-managed.md](references/nix-managed.md) |

## Reference index

| Topic | File |
|---|---|
| Man-page sections, search, `MANPATH`, large-page extraction | [references/man-pages.md](references/man-pages.md) |
| GNU Info pages, navigation, non-interactive extraction | [references/info-pages.md](references/info-pages.md) |
| Shell builtins, `--help`, safety checks | [references/inline-help.md](references/inline-help.md) |
| Bundled docs in `/usr/share/doc/`, package-manager lookup | [references/bundled-docs.md](references/bundled-docs.md) |
| Step-by-step search strategy when you don't know where to look | [references/search.md](references/search.md) |
| Nix-managed systems (multi-tier MANPATH, `nix repl :doc`) | [references/nix-managed.md](references/nix-managed.md) |

## Most common usage

```bash
# Open the page (searches sections in order).
man grep

# Specific section.
man 5 crontab

# Search descriptions across all installed man pages.
man -k <keyword>

# One-line description.
man -f <name>

# Where is this man page on disk? (which package provides it).
man -w <name>
```

## Extracting from large man pages

`man bash` is ~5000 lines; configuration references can be larger.
Extract instead of reading whole:

```bash
# Find a specific option.
man <page> | col -bx | grep -A 15 '<pattern>'

# Extract a named section.
man <page> | col -bx | sed -n '/^ENVIRONMENT/,/^[A-Z]/p'
```

`col -bx` strips backspace-based formatting so grep is reliable.

## Hard rules

- **Man / info first; web search last.** Local docs are authoritative
  for the installed version.
- **`--help` is code execution.** Verify trust before running.
- **Specify the section** when a name exists in multiple
  (`man 3 printf`, not `man printf`).
- **Use `col -bx`** when piping man output to grep / sed — backspace
  formatting otherwise breaks pattern matches.
- **`help`, not `man`, for shell builtins.** `cd`, `export`, `alias`
  often have no man page.
- **Check Nix-managed docs** ([references/nix-managed.md](references/nix-managed.md))
  on NixOS / Home Manager hosts before assuming docs are missing.

## Cross-references

- **Nix-managed systems** (NixOS, Home Manager): read
  [references/nix-managed.md](references/nix-managed.md) for
  multi-tier `MANPATH`, `nix repl :doc`, configuration-reference man
  pages, and Nix CLI documentation.
- **Language-specific docs** (godoc, rustdoc, pydoc, perldoc): covered
  by their respective language skills, not this one.
