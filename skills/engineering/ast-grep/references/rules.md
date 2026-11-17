# YAML rules and `ast-grep scan`

Use `scan` for repeatable rules with messages, fixes, and severity.
`run` is for one-shots; `scan` is for the persistent rules a project
ships.

## Scaffolding

```bash
ast-grep new project          # scaffolds sgconfig.yml + rules/ + rule-tests/ + utils/
ast-grep new rule no-eval -l js
```

`new project` creates the standard layout; `new rule` produces a
template at `rules/<id>.yml` plus a paired test at
`rule-tests/<id>-test.yml`.

## Running

```bash
ast-grep scan                                 # uses sgconfig.yml from CWD or parents
ast-grep scan -r rule.yml                     # one-off rule file
ast-grep scan --inline-rules '{id: x, language: js, rule: {pattern: eval($A)}}'
ast-grep scan --filter '^security-' --json=stream
ast-grep scan -U                              # apply all fixes without prompting
ast-grep scan --error                         # exit non-zero on any error-severity match (CI)
```

`scan` walks the project from the directory containing `sgconfig.yml`;
it respects `.gitignore` by default.

## Rule file shape

```yaml
id: no-eval
language: JavaScript
severity: error
message: Avoid eval; it executes arbitrary code.
note: Use JSON.parse or a real parser.
rule:
  pattern: eval($CODE)
fix: JSON.parse($CODE)
```

| Key | Meaning |
|--------------|----------------------------------------------------------|
| `id` | Unique identifier; used by `--filter` and tests. |
| `language` | One of the supported languages (JavaScript, TypeScript, Python, …). |
| `severity` | `error`, `warning`, `info`, `hint`. |
| `message` | One-line summary shown for each match. |
| `note` | Optional longer explanation / rationale. |
| `rule` | The matcher (see operators below). |
| `fix` | Optional rewrite template. |
| `constraints`| Per-meta-variable filters. |

## Rule operators

### Atomic

| Operator | Use |
|-------------|------------------------------------------------------|
| `pattern` | Source-code pattern (the canonical form). |
| `kind` | Match by tree-sitter node kind (advanced). |
| `regex` | Match the matched text against a regex. |
| `nthChild` | Match by position within parent. |
| `range` | Match a literal source range. |

Prefer `pattern` over `kind` when both work — `kind` breaks on
grammar upgrades.

### Relational

| Operator | Use |
|------------|-------------------------------------------------------|
| `inside` | Match nodes inside another rule's matches. |
| `has` | Match nodes that contain a sub-rule's matches. |
| `precedes` | Match nodes preceded by sub-rule matches. |
| `follows` | Match nodes followed by sub-rule matches. |

Each takes a sub-rule plus optional:

- `stopBy: end | neighbor | <rule>` — how far to traverse.
- `field: <name>` — restrict to a named field (e.g.
  `field: parameter` to match function parameters specifically).

### Composite

| Operator | Use |
|----------|-------------------------------------------------------------|
| `all` | AND — all sub-rules must match the same node. |
| `any` | OR — at least one sub-rule matches. |
| `not` | Negate a sub-rule. |
| `matches`| Reference a named rule in `utils:`. |

### `constraints`

Per-meta-variable filters:

```yaml
rule:
  pattern: fetch($URL)
constraints:
  URL:
    regex: '^["'']http://'   # only flag plain http
```

`constraints` is the per-variable filter knob. Use when the
structural pattern is right but you need to narrow by string content,
kind, or another regex.

## Reusable utilities

`utils:` in `sgconfig.yml` or inside a rule defines named sub-rules
reused via `matches: <id>`:

```yaml
# In sgconfig.yml.
utils:
  is-test-file:
    kind: program
    has:
      kind: import_statement
      regex: "from ['\"]vitest['\"]"

# In a rule.
rule:
  all:
    - matches: is-test-file
    - pattern: console.log($_)
```

**Promote duplication.** Any sub-rule that appears in two places
belongs in `utils:`.

## Rewriters

Multiple fix templates selected by sub-rule — useful when one rule
produces different rewrites for different cases:

```yaml
rule:
  pattern: $X.$METHOD($$$)
rewriters:
  - id: rename-foo
    rule:
      pattern: $_.foo($$$)
    fix: $X.bar($$$)
  - id: rename-baz
    rule:
      pattern: $_.baz($$$)
    fix: $X.qux($$$)
```

## `sgconfig.yml`

```yaml
ruleDirs:
  - rules
testConfigs:
  - testDir: rule-tests
utilDirs:
  - utils
```

`ast-grep` walks up from CWD to find `sgconfig.yml`, so `scan` works
from any subdirectory of the project. Each entry is relative to the
config file's location.

## Full reference

Rule schema and corner cases:
<https://ast-grep.github.io/reference/rule.html>
