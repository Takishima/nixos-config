# Pattern syntax

Patterns are real source code in the target language with meta-variable
holes. The parser is the language's tree-sitter grammar, so anything
syntactically valid in the language is a valid pattern.

## Meta-variables

| Token | Matches |
|-------------|-----------------------------------------------------------------|
| `$VAR` | Exactly one named AST node; the same name must match identically.|
| `$_` | Exactly one anonymous node (don't capture). |
| `$$VAR` | Exactly one *unnamed* node (vs. `$VAR` which matches named). |
| `$$$` | Ellipsis: any number of sibling nodes (args, statements, items).|
| `$$$VAR` | Named ellipsis: capture the sequence for use in `--rewrite`. |

Named vs anonymous: tree-sitter distinguishes "named" nodes (function
calls, statements, declarations) from "anonymous" nodes (punctuation,
keywords, operators). Most user-facing patterns match named nodes;
`$$VAR` is the escape hatch when you genuinely need to capture an
anonymous token.

## Capture semantics

Same name → same content:

```bash
# Matches when both args are the same identifier.
ast-grep -p 'assertEqual($X, $X)' -l py
```

Reuse in rewrite:

```bash
ast-grep -p 'foo($X, $Y)' -r 'bar($Y, $X)' -l js
```

`$$$VAR` captures the whole sequence:

```bash
ast-grep -p 'console.log($$$ARGS)' -r 'logger.debug($$$ARGS)' -l ts
```

## Recipes

### Find every console method call

```bash
ast-grep -p 'console.$METHOD($$$)' -l ts
```

`$METHOD` captures the method name (`log`, `warn`, `error`, …).

### Promise.then with arrow callback

```bash
ast-grep -p '$P.then($X => $$$)' -l js
```

Captures the receiver, the arrow's parameter, and the body sequence.

### Empty catch block

```bash
ast-grep -p 'try { $$$ } catch ($_) { }' -l ts
```

`$_` for the catch parameter (don't capture); empty `{ }` for the
body.

### Function that calls a specific API

```bash
# Functions that call fetch().
ast-grep -p 'function $NAME($$$) { $$$; fetch($$$); $$$; }' -l js
```

The three `$$$` allow any prologue, the `fetch(...)` line, and any
epilogue.

### Decorator presence

```bash
ast-grep -p '@$DECORATOR
def $FN($$$): $$$' -l py
```

Multi-line patterns are fine; whitespace doesn't matter.

### Specific argument shape

```bash
# Calls where the second argument is a string literal.
ast-grep -p 'foo($_, "$STR")' -l js
```

`"$STR"` captures the string contents inside a string literal.

## When patterns don't match

Three common causes:

1. **Pattern parses differently than you think.** Run
   `ast-grep --debug-query -p '<pattern>' -l <lang>` and compare to
   the parse of a known-matching source.
1. **Named vs anonymous node mismatch.** If your pattern references
   a keyword (`return`, `let`, `const`), you may need `$$VAR` for the
   anonymous variant.
1. **Tree-sitter grammar version drift.** ast-grep upgrades grammars
   between releases; a pattern that worked may need adjustment.
   `--debug-query` is the diagnostic.

## YAML rule patterns

Inside a YAML rule, `pattern:` takes the same syntax:

```yaml
rule:
  pattern: console.log($A)
```

For multi-line patterns or patterns that need escaping, use the
literal-block scalar:

```yaml
rule:
  pattern: |
    try {
      $$$
    } catch ($_) { }
```

## Pattern reference

Full grammar and corner cases:
<https://ast-grep.github.io/guide/pattern-syntax.html>
