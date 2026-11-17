# Footguns

## Pattern looks right but doesn't match

The single most common ast-grep problem. Almost always a tree-sitter
parse mismatch.

```bash
ast-grep --debug-query -p '<the pattern>' -l <lang>
```

The output shows how ast-grep parsed your pattern. Compare against:

```bash
echo '<known-good source snippet>' | ast-grep --debug-query --stdin -l <lang>
```

The two parses should look structurally identical at the
meta-variable hole positions. If they don't, adjust the pattern.

## `-l` is required when

- Reading from stdin (`--stdin`) — no file extension to infer from.
- File extension is ambiguous (`.h` for C vs C++, `.ts` for
  TypeScript vs Typoscript).
- Inside a YAML rule (the `language:` field is required).

Without `-l`, you get either "Cannot determine language" or, worse,
the wrong language inferred — silent zero-match results.

## Tree-sitter grammar drift

Rules tied to a specific `kind:` can break when ast-grep upgrades a
tree-sitter grammar between releases. The kind name might be renamed
or restructured.

Mitigations:

- **Prefer `pattern:` over `kind:` when both work.** Patterns are
  more stable across grammar revisions.
- **Keep snapshot tests.** `ast-grep test --snapshots` catches drift
  as a failing test rather than silent under-matching in prod.

## `fix` is a template, not code

`$VAR` in `fix:` is substituted *textually*. The result must be
syntactically valid in the language after substitution.

```yaml
# WRONG — Output is "foo.bar." (trailing dot on no-args call).
rule:
  pattern: $A.foo($$$ARGS)
fix: $A.bar.$$$ARGS

# RIGHT.
fix: $A.bar($$$ARGS)
```

When precedence matters, wrap in parentheses:

```yaml
# WRONG — produces e.g. "x || y?.foo" with wrong precedence.
fix: $A?.foo

# RIGHT.
fix: '($A)?.foo'
```

## Captured ellipsis vs un-captured

```bash
# Captures the arg sequence (use $$$ARGS in --rewrite).
ast-grep -p 'foo($$$ARGS)' -r 'bar($$$ARGS)' -l js

# Doesn't capture — $$$ is the "any number" wildcard.
ast-grep -p 'foo($$$)' -l js
```

If you forget the `VAR` suffix on the ellipsis, the rewrite can't
reference it.

## Pattern doesn't survive editor formatting

A pattern that works for `foo(a, b, c)` may not work for `foo(a, b, c,)` (trailing comma) in some grammars. The fix: re-test the pattern
on both styles, and/or normalise via `--debug-query` to confirm both
parse the same way at the pattern position.

## Multi-line patterns in shells

```bash
# WRONG — shell collapses newlines.
ast-grep -p 'try {
  $$$
} catch ($_) { }' -l ts

# RIGHT — read pattern from file.
ast-grep -p "$(cat pattern.txt)" -l ts

# Or use a single-line pattern (often works).
ast-grep -p 'try { $$$ } catch ($_) { }' -l ts
```

Single-line patterns usually work even when the actual code is
multi-line — tree-sitter normalises whitespace.

## Plain string search

```bash
# WRONG tool — ast-grep parses and matches; this is slow for plain
# string search and the pattern would fire on AST nodes that contain
# the literal "TODO" as content, including comments, strings, etc.
ast-grep -p 'TODO' -l ts src/

# RIGHT tool.
rg 'TODO' src/
```

ast-grep is structural; `rg` is faster and clearer for non-structural
matches.

## YAML quoting

```yaml
# Inside a YAML rule:

# WRONG — colon parsed as a YAML mapping.
pattern: foo: $X

# RIGHT — quote the value.
pattern: "foo: $X"

# Multi-line, also works.
pattern: |
  foo: $X
```

YAML's quoting rules and ast-grep's pattern syntax sometimes
collide. When in doubt, double-quote or use a block scalar.

## Don't shadow a real binary

The `sg` alias collides with `/usr/bin/sg` (setgid wrapper) on some
distributions. Use `ast-grep` in scripts. The alias is fine for
interactive use on hosts where you know it's not shadowed.
