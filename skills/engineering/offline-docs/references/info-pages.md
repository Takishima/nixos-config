# GNU Info pages

GNU Info provides structured, hyperlinked documentation. Some GNU
tools have minimal man pages that say "see info for the full
manual" — in those cases, info is the authoritative source.

## When to use info

- The man page says "The full documentation is maintained as a
  Texinfo manual".
- You need comprehensive coverage of `bash`, `coreutils`, `make`,
  `grep`, `sed`, `awk`, `gzip`, or `texinfo`.
- You want a structured reference rather than a flat man page.

## Interactive reading

```bash
info <topic>                    # open interactively
info <topic> '<node name>'      # jump to a specific section
```

Navigation:

- `n` — next node (same level).
- `p` — previous node.
- `u` — up one level.
- `]` / `[` — next / previous node in document order.
- `/` — search.
- `s` — incremental search.
- `q` — quit.

The cursor jumps between nodes via `Enter` on hyperlink-style menu
items (`*Note ...::`).

## Non-interactive extraction

For agent-driven use, dump the relevant section directly:

```bash
# Dump a specific node to stdout.
info <topic> '<node name>' --output=-

# Dump everything (large — pipe to grep / less).
info <topic> --subnodes --output=- | grep -A 10 '<pattern>'
```

`--subnodes` recurses into child nodes; without it you only get the
named node's immediate content.

## Key info pages

| Topic | Coverage |
|---|---|
| `bash` | Complete shell reference — builtins, expansion, scripting. |
| `coreutils` | All GNU core utilities in detail. |
| `make` | GNU Make manual. |
| `grep`, `sed`, `awk` | Pattern matching and text processing. |
| `texinfo` | The Info format itself. |
| `gcc` | GNU compiler reference (huge). |
| `gdb` | Debugger reference. |

## When info isn't installed

Some distributions ship without the `info` reader (`texinfo`
package). Two fallbacks:

1. **Read the .info files directly.** They live in `/usr/share/info/`
   and are plain (somewhat) text:
   ```bash
   less /usr/share/info/bash.info.gz
   ```
1. **`pinfo`** — alternative reader with less arcane key bindings.

For most CLI tools, the man page is enough; info is the fallback for
the few GNU tools whose documentation grew too large for the man
format.

## info node references in man pages

Man pages cross-reference info nodes via the `SEE ALSO` section:

```
SEE ALSO
       info gawk - more detailed manual
```

When you see this, the man page is the executive summary; the info
manual is the full reference.

## Common pitfalls

- **`info bash` opens the top-level Info directory** when bash isn't
  the configured top topic. Use `info '(bash)'` to force the
  specific manual.
- **Search inside info uses different syntax** than man's pager —
  `/` works but doesn't always find what you'd expect across nodes.
  Use `s` (incremental) for cross-node search.
- **Info uses ANSI escapes** in some terminals; pipe to `col -b` if
  grepping output and the matches don't fire.
