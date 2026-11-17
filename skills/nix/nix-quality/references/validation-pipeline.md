# Validation pipeline

End-to-end bash script for repo-wide validation. Exits non-zero on the first
failed stage. Missing optional tools warn but don't fail.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> 1. Format"
if command -v nixfmt &>/dev/null; then
  nixfmt --check . || { echo "✗ Run 'nixfmt .' to fix"; exit 1; }
else
  echo "⚠ nixfmt not found"
fi

echo "==> 2. Lint (statix)"
if command -v statix &>/dev/null; then
  statix check . || exit 1
else
  echo "⚠ statix not found"
fi

echo "==> 3. Dead code (deadnix)"
if command -v deadnix &>/dev/null; then
  deadnix --fail . || { echo "✗ Run 'deadnix -e' to remove"; exit 1; }
else
  echo "⚠ deadnix not found"
fi

echo "==> 4. Evaluation"
if [[ -f flake.nix ]]; then
  nix flake check --no-build
elif [[ -f default.nix ]]; then
  nix-instantiate --eval --strict default.nix > /dev/null
fi

echo "==> 5. Dry build (if flake)"
if [[ -f flake.nix ]]; then
  nix build --dry-run .#default 2>&1 | tail -5
fi

echo "✓ All stages passed"
```

## Per-tool quick reference

### nixfmt (RFC 166 style)

```bash
nixfmt .            # format in place
nixfmt --check .    # check only
nix fmt             # via flake formatter
```

The `nixfmt-rfc-style` binary is the official style; the older `nixfmt` /
`nixfmt-classic` are legacy.

### statix

```bash
statix check
statix check --explain
statix fix              # apply safe fixes
statix check --ignore redundant_pattern_bind
```

Common warning IDs: `empty_let_in`, `manual_inherit`, `useless_parens`,
`bool_comparison`, `eta_reduction`.

### deadnix

```bash
deadnix             # report
deadnix --fail      # exit non-zero on findings (CI)
deadnix -e          # *edit files* to remove
deadnix --no-lambda-arg     # ignore unused lambda args
deadnix --no-underscore     # ignore _-prefixed bindings
```

`-e` modifies files. Run from a clean working tree so you can `git diff` the
result.
