# `ast-grep run` reference

`run` is the default subcommand. `ast-grep -p ...` and
`ast-grep run -p ...` are equivalent.

## Common invocations

```bash
# Find a pattern in TypeScript sources.
ast-grep -p 'console.log($A)' -l ts src/

# Rewrite to a new form.
ast-grep -p 'console.log($A)' -r 'logger.debug($A)' -l ts src/

# Stream JSON for downstream tools.
ast-grep -p 'foo($$$)' -l js --json=stream | jq .

# Read from stdin.
echo 'function foo() { return null; }' | ast-grep -p 'return null' -l js --stdin

# Interactive rewrite (confirm each replacement).
ast-grep -p 'console.log($A)' -r 'logger.debug($A)' -l ts -i src/

# Apply all rewrites without prompting.
ast-grep -p 'console.log($A)' -r 'logger.debug($A)' -l ts -U src/
```

## Key flags

| Flag | Use |
|-------------------------------|----------------------------------------------------------------|
| `-p`, `--pattern` | Pattern source. |
| `-r`, `--rewrite` | Replacement template. |
| `-l`, `--lang` | Explicit language. Inferred from file extension if omitted. |
| `-i`, `--interactive` | Confirm each rewrite. |
| `-U`, `--update-all` | Apply all rewrites without prompting. |
| `--stdin` | Read code from stdin. |
| `--json=pretty\|stream\|compact` | Machine-readable output. |
| `-A N`, `-B N`, `-C N` | Context lines (like `grep`). |
| `--globs '<pattern>'` | Include / exclude paths (repeat for multiple). |
| `--debug-query -l <lang>` | Print the tree-sitter parse of the pattern. First thing to try when a pattern refuses to match. |
| `--color always\|never\|auto` | Colour control. |

## Supported languages

Pass any of these to `-l`:

```
js, ts, tsx, py, go, rust, java, kotlin, c, cpp, csharp,
ruby, php, swift, bash, html, css, json, yaml
```

Language inference uses file extensions; ambiguous ones (`.h` could
be C or C++; `.ts` could be TypeScript or Typoscript) require
explicit `-l`.

## stdin mode

```bash
cat src/foo.ts | ast-grep -p 'console.log($A)' -l ts --stdin
```

`--stdin` is required when piping; without it, ast-grep reads the
file by name and fails (no positional argument).

`-l` is mandatory under `--stdin` — there's no file extension to
infer from.

## JSON output shape

```bash
ast-grep -p 'console.log($A)' -l ts --json=stream src/
```

Each match is one JSON object per line:

```json
{
  "file": "src/foo.ts",
  "range": {"start": {"line": 12, "column": 4}, "end": {...}},
  "metaVariables": { "single": {"A": {"text": "\"hello\"", ...}} },
  "lines": "    console.log(\"hello\");"
}
```

`--json=pretty` for human reading; `--json=stream` for `jq -c` /
line-delimited consumers; `--json=compact` for the smallest size
(no whitespace).

## Globbing

```bash
ast-grep -p 'pattern' --globs '!**/*_test.ts' --globs 'src/**' src/
```

Globs filter the file set ast-grep visits. The first `!` is the
exclude prefix; subsequent globs are includes. Default behaviour
respects `.gitignore`.

## Debugging a pattern

When the pattern looks right but matches nothing:

```bash
ast-grep --debug-query -p 'console.log($A)' -l ts
```

Prints the tree-sitter parse of the pattern (kinds and structure).
Compare against `ast-grep --debug-query` on a known-matching source
snippet to find the discrepancy.
