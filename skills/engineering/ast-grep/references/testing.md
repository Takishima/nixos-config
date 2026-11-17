# Rule testing with `ast-grep test`

Each shipped rule ships with a sibling test file at
`rule-tests/<id>-test.yml`. `ast-grep test` runs them; `--snapshots`
locks in golden fixes; `-U` updates snapshots.

## Layout

```
project/
├── sgconfig.yml
├── rules/
│   └── no-eval.yml
├── rule-tests/
│   └── no-eval-test.yml
└── utils/
```

`testConfigs.testDir` in `sgconfig.yml` points at the test directory:

```yaml
testConfigs:
  - testDir: rule-tests
```

## Test file shape

```yaml
id: no-eval
valid:
  - JSON.parse(input)
  - require('module')
  - var x = 1;
invalid:
  - eval(code)
  - eval("alert('hi')")
  - "if (cond) { eval(code); }"
```

- **`valid`** — snippets the rule must NOT match. If the rule
  matches any, the test fails.
- **`invalid`** — snippets the rule MUST match. If the rule misses
  any, the test fails.

Each list item is a string. Multi-line snippets use the YAML literal
block scalar:

```yaml
invalid:
  - |
    function dangerous(code) {
      eval(code);
    }
```

## Running

```bash
ast-grep test                # run all rule tests
ast-grep test -f no-eval     # filter by id regex
ast-grep test --snapshots    # also run snapshot tests
ast-grep test -U             # accept new snapshots (updates fixtures)
```

`-U` is destructive — review the diff before committing. Treat
snapshot updates like accepting golden files in any other test
framework.

## Snapshots

Snapshot tests assert the *fix* (rewrite) produces an expected output.
Useful for rules with non-trivial `fix:` templates.

Workflow:

1. Author the rule with a `fix:` template.
1. Run `ast-grep test -U` to capture the snapshot.
1. Inspect the generated `__snapshots__/<id>.snap.yml` — confirm the
   rewrite is what you intended.
1. Commit both the rule and the snapshot.

Subsequent runs of `ast-grep test --snapshots` re-apply the rule and
diff against the snapshot. Breaking changes show as test failures.

## CI integration

```yaml
# .github/workflows/ast-grep.yml
- name: ast-grep test
  run: ast-grep test --snapshots

- name: ast-grep scan
  run: ast-grep scan --error
```

`test --snapshots` verifies rule behaviour hasn't drifted; `scan --error` enforces the rules against the actual codebase.

## What to test

Every shipped rule, minimally:

- One `valid` snippet that *closely resembles* the invalid form but
  shouldn't match (catches over-broad patterns).
- One `invalid` snippet that the rule was written for.
- One `invalid` snippet that's *almost* the obvious form but uses a
  different identifier / formatting (catches under-broad patterns).

If the rule has a `fix:` template, add a snapshot test for the
rewrite.

## Tree-sitter grammar drift

The most common reason a previously-passing rule test starts failing
is an ast-grep version bump that updates a tree-sitter grammar. The
fix:

1. Run `ast-grep --debug-query -p '<the pattern>' -l <lang>` on both
   the old and new ast-grep versions.
1. Adjust the pattern to match the new parse.
1. Update the snapshot if the rewrite output also changed.

Snapshots are how you'd notice grammar drift in the first place —
they're worth the upkeep for any rule that ships in production.
