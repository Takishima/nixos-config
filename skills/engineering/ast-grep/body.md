> Vendored from [jylhis/skills](https://github.com/jylhis/skills) (source-of-truth: `~/Developer/jylhis/skills`).

# ast-grep

`ast-grep` (CLI binary `ast-grep`, alias `sg`) is a polyglot
tree-sitter-backed tool for structural code search, lint, and rewrite.
Use it whenever a `grep` / `sed` regex would be brittle: it matches on
the parsed AST, so formatting, whitespace, and comments don't matter.

## When to use

- API migrations: rename a function, change a signature, swap a
  decorator.
- Codemods across a large repo.
- Finding insecure or deprecated patterns (`eval`, `unsafe`, `any`).
- Enforcing in-house lint rules across multiple languages with one
  tool.
- Anything where a regex would over- or under-match because of
  formatting.

**Don't use it for plain string search.** `rg` is faster and clearer
for non-structural matches.

## Canonical one-liners

```bash
# Find every console.log call in TypeScript sources.
ast-grep -p 'console.log($A)' -l ts src/

# Rewrite console.log(...) to logger.debug(...).
ast-grep -p 'console.log($A)' -r 'logger.debug($A)' -l ts src/

# Stream JSON for downstream tools.
ast-grep -p 'foo($$$)' -l js --json=stream | jq .
```

## Binary name

- `ast-grep` everywhere.
- `sg` alias exists on most distributions; on some systems `sg`
  collides with `/usr/bin/sg` (setgid wrapper). Use `ast-grep` in
  scripts.

## Reference index

| Topic | File |
|---|---|
| `ast-grep run` flags, language inference, debug-query | [references/run.md](references/run.md) |
| Meta-variable syntax (`$VAR`, `$_`, `$$$`), pattern recipes | [references/patterns.md](references/patterns.md) |
| YAML rules, `scan`, rule operators, `sgconfig.yml` | [references/rules.md](references/rules.md) |
| `ast-grep test`, snapshots, rule-tests/ layout | [references/testing.md](references/testing.md) |
| Common idioms, CI usage, hybrid lint | [references/idioms.md](references/idioms.md) |
| Footguns and how to debug them | [references/footguns.md](references/footguns.md) |

## Quick pattern primer

Patterns are real source code in the target language with
meta-variable holes:

| Token | Matches |
|-------------|-----------------------------------------------------------------|
| `$VAR` | Exactly one named AST node; same name must match identically. |
| `$_` | Exactly one anonymous node (don't capture). |
| `$$VAR` | Exactly one *unnamed* node, captured. |
| `$$$` | Ellipsis: any number of sibling nodes. |
| `$$$VAR` | Named ellipsis: capture the sequence for `--rewrite`. |

Three examples — full catalogue in
[references/patterns.md](references/patterns.md):

```bash
# Any console method.
ast-grep -p 'console.$METHOD($$$)' -l ts

# Promise.then with arrow callback.
ast-grep -p '$P.then($X => $$$)' -l js

# Empty catch block.
ast-grep -p 'try { $$$ } catch ($_) { }' -l ts
```

## Hard rules

- **Pattern doesn't match? Run `--debug-query -l <lang>`.** Shows
  the tree-sitter parse of the pattern — the first thing to reach
  for when a one-liner refuses to fire.
- **`-l` is required for stdin** and ambiguous extensions (`.h`,
  `.ts`). Don't trust auto-inference for non-`.js` / `.ts` / `.py`
  files.
- **Prefer `pattern:` over raw `kind:`** when both work. `kind:`
  rules break on grammar upgrades; pattern rules are stable.
- **`fix` is a template, not code.** `$VAR` is substituted
  textually — wrap in parentheses if precedence matters
  (`fix: '($A)?.foo'`).
- **Promote duplicated sub-rules to `utils`.** Any rule logic
  copy-pasted in two places belongs in `utils/` and referenced via
  `matches: <id>`.
- **Tests for every shipped rule.** `rule-tests/<id>-test.yml` with
  both `valid` and `invalid` cases; `ast-grep test` runs them.

## Tool detection

```bash
for tool in ast-grep jq rg; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

`jq` and `rg` aren't required, but most workflows that consume
`--json` output or pre-filter files for ast-grep use them.

## Useful links

- Docs: <https://ast-grep.github.io/>
- Pattern reference: <https://ast-grep.github.io/guide/pattern-syntax.html>
- Rule reference: <https://ast-grep.github.io/reference/rule.html>
- CLI reference: <https://ast-grep.github.io/reference/cli.html>
- Rule catalog (copy-paste examples): <https://ast-grep.github.io/catalog/>
- Playground (paste code, iterate on patterns): <https://ast-grep.github.io/playground.html>
