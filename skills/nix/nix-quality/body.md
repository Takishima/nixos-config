# Nix code quality

Use this skill when reviewing Nix code, before committing changes, when
diagnosing slow evaluation, or when a build/eval fails in a way that points
at an anti-pattern (infinite recursion, undefined variable, hash mismatch).

This skill is also the canonical reference for Nix anti-patterns — other
Nix skills link here instead of duplicating the catalog.

## Validation pipeline

Run in this order; later stages waste time if earlier ones fail:

```bash
# 1. Format — fast, mechanical
nixfmt .                     # or `nix fmt` if the flake declares a formatter

# 2. Lint — catches anti-patterns
statix check .

# 3. Dead code
deadnix --fail .

# 4. Evaluation — does the flake/file even parse and type-check
nix flake check --no-build   # for flakes
nix-instantiate --eval --strict default.nix   # for non-flake

# 5. Dry build — catches missing inputs / wrong hashes without doing work
nix build --dry-run .#default
```

For a turn-key bash wrapper that runs all stages with clear exit codes, see
[references/validation-pipeline.md](references/validation-pipeline.md).

### Auto-fix where safe

- `nixfmt .` — formatting only.
- `statix fix` — applies safe lint fixes (eta reductions, `inherit`
  shorthand, redundant parens). Review the diff before committing.
- `deadnix -e` — *deletes* unused bindings. Run interactively; it's
  destructive.

## Triaging by severity

Anti-patterns split into three buckets by what they cost. Severity drives
fix order — never spend time on a moderate issue while a critical one is
masking it.

| Severity | What it does | Fix order |
|----------|-------------|-----------|
| **Critical** | Infinite recursion, eval failure, non-reproducible builds | Drop everything, fix first |
| **High** | Slow eval (often 2–10×), excess memory, wasted CPU | Fix once functionality lands |
| **Moderate** | Readability, future-you cost, lint noise | Roll into normal cleanup |

The catalog for each bucket — with detection patterns, root cause, and the
fix — lives in [references/anti-patterns.md](references/anti-patterns.md).

The most frequent offenders to spot-check first:

- `final.X` inside the definition of `X` → infinite recursion (overlays).
- Unquoted URLs (`url = https://…;`) → deprecated syntax.
- Top-level `with pkgs;` → ambiguous scope, shadowing.
- `import <nixpkgs> {}` in production → unpinned, non-reproducible.
- IFD (Import From Derivation) → kills parallel eval.
- `lib.foldl (acc: x: acc // { … })` → O(n²). Use `lib.mergeAttrsList`.

## Performance debugging

When eval feels slow:

```bash
NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH=stats.json \
  nix-instantiate --eval test.nix
jq '{ thunks: .nrThunks, cpuMs: .cpuTime, bytes: .gc.totalBytes }' stats.json
```

Compare against a known-good baseline. Suspect overlays first
(see `nix-overlays` → `references/performance.md`), then check for IFD with
`nix-instantiate --eval --debugger`.

For build-time profiling (`nixprof`, `nix-tree`, `nix why-depends`), see
[references/profiling.md](references/profiling.md).

## Testing

Three levels, pick the lightest that catches the bug class you care about:

```nix
# Unit — pure functions
testMyFunction = {
  expr     = myFunction { input = "test"; };
  expected = "expected output";
};

# Integration — overlay / module composition
testOverlayComposition = {
  expr = let
    o1 = final: prev: { x = "value"; };
    o2 = final: prev: { y = final.x + "-ext"; };
    pkgs = import nixpkgs { overlays = [ o1 o2 ]; };
  in pkgs.y;
  expected = "value-ext";
};

# NixOS VM tests — actual systemd services / network
testMyModule = nixosTest {
  name = "mymodule";
  nodes.machine = { ... }: { imports = [ ./module.nix ]; };
  testScript = ''
    machine.wait_for_unit("myservice.service")
    machine.succeed("curl localhost:8080")
  '';
};
```

More patterns (try/catch with `tryEval`, NixOS-test helpers, test-harness
runners) in [references/testing.md](references/testing.md).

## Common failure modes

| Symptom | First thing to try |
|---------|--------------------|
| `infinite recursion encountered` | Find `final.X` inside `X = …`; switch to `prev.X` |
| `error: hash mismatch` | Replace the hash with `lib.fakeHash`, rebuild, copy the actual hash from the error |
| `command not found` at build time | Add to `nativeBuildInputs` (build-time) or `buildInputs` (runtime/link) |
| `error: undefined variable` | Likely a `with` scope you removed or an `inherit` you forgot |
| Eval hangs / OOMs | IFD or quadratic merge — see anti-patterns reference |

For full debugging recipes (repl exploration, `--show-trace`, cache reset),
see [references/debugging.md](references/debugging.md).

## References

- [references/anti-patterns.md](references/anti-patterns.md) — full
  catalog: critical / high / moderate buckets, code examples, root causes.
- [references/validation-pipeline.md](references/validation-pipeline.md) —
  the bash wrapper for nixfmt / statix / deadnix / flake check.
- [references/profiling.md](references/profiling.md) — `nixprof`,
  `nix-diff`, `nix-tree`, `NIX_SHOW_STATS` interpretation.
- [references/testing.md](references/testing.md) — unit / integration /
  NixOS tests.
- [references/debugging.md](references/debugging.md) — repl, `--show-trace`,
  hash recovery, cache reset, infinite-recursion hunting.
