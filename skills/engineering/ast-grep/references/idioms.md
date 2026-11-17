# Common idioms

## Match-only, no fix

Omit `fix`. The rule still reports — useful for "this pattern exists,
review manually" cases:

```yaml
id: any-cast
language: TypeScript
severity: warning
message: Explicit `as any` cast — review for type safety.
rule:
  pattern: $X as any
```

## CI lint with non-zero exit

```bash
ast-grep scan --error      # exits non-zero on any error-severity match
```

Wire into CI alongside other linters. `--error` exits 1 if any rule
with `severity: error` matched; warnings and below don't fail the
build.

## Codemod with review

```bash
ast-grep scan -i           # interactive — confirm each rewrite
ast-grep scan -U           # apply all rewrites without prompting
```

For large rewrites:

1. `ast-grep scan` (no flags) to count matches.
1. `ast-grep scan -i` on a representative subset to spot-check the
   rewrites.
1. `ast-grep scan -U` once confident.
1. `git diff` to review before committing.

## Stream to other tools

```bash
ast-grep --json=stream -p 'pattern' -l ts src/ | jq -c .

# Count matches per file.
ast-grep --json=stream -p 'pattern' -l ts src/ \
  | jq -r .file | sort | uniq -c | sort -rn

# Filter matches by metaVariable content.
ast-grep --json=stream -p 'fetch($URL)' -l js src/ \
  | jq 'select(.metaVariables.single.URL.text | startswith("\"http://"))'
```

`--json=stream` emits one JSON object per match per line — ideal for
piping through `jq`, `grep`, or custom tools.

## Hybrid lint

ast-grep doesn't replace Ruff / ESLint / Clippy / SwiftLint —
language-specific linters have richer type info and better diagnostics
for in-language rules.

Use ast-grep alongside them for:

- **Cross-language rules** (forbid `console.log` in JS AND `print` in
  Python AND `println!` in Rust with one ruleset).
- **Project-specific rules** the language linter can't express (your
  internal API conventions, deprecated wrappers, ban a specific
  symbol).
- **Codemods** for migrations — neither ESLint nor Clippy is built
  for "rewrite N call sites across the repo".

## Pre-commit hook

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: ast-grep
        name: ast-grep scan
        entry: ast-grep scan --error
        language: system
        types: [text]
        pass_filenames: false
```

`pass_filenames: false` lets ast-grep walk the project via its own
`sgconfig.yml` and `.gitignore` integration; pre-commit just triggers
the run.

## Inline rule for one-off CI

```bash
ast-grep scan --inline-rules '
  id: forbid-todo
  language: JavaScript
  severity: error
  message: TODO comments not allowed in production code.
  rule:
    kind: comment
    regex: "TODO"
'
```

Useful for CI-only rules that don't belong in `rules/` (one-shot
migration checks, branch-specific gates).

## Find-and-list before rewrite

```bash
# First, count and see the matches.
ast-grep -p 'console.log($A)' -l ts src/

# Spot-check on a subset.
ast-grep -p 'console.log($A)' -r 'logger.debug($A)' -l ts src/lib/foo.ts -i

# Apply to the whole tree.
ast-grep -p 'console.log($A)' -r 'logger.debug($A)' -l ts -U src/
```

Never `-U` cold; always preview the count first. Rewrites are
mechanical; bugs in the pattern produce many wrong changes at once.
