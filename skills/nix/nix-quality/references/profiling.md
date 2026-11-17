# Performance profiling

## Eval stats

```bash
NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH=stats.json \
  nix-instantiate --eval test.nix

jq '{
  cpuMs:      .cpuTime,
  thunks:     .nrThunks,
  totalBytes: .gc.totalBytes,
  envs:       .nrEnvs
}' stats.json
```

Compare before/after for any change. A doubling of `nrThunks` for an
unrelated change is almost always a quadratic-merge or accidental
`final.callPackage` regression.

For flakes:

```bash
NIX_SHOW_STATS=1 nix eval .#packages.x86_64-linux.default 2>&1 | tail -20
```

## Build profiling

### `nixprof`

```bash
nix shell github:Kha/nixprof
nixprof record nix build .#package
nixprof report --all
```

Shows per-derivation wall-clock; useful when one bad dep dominates a slow
build.

### Derivation diff

```bash
nix-diff $(nix-instantiate old.nix) $(nix-instantiate new.nix)
```

Exactly which build inputs changed between two states. Critical when a
trivial-looking change triggers a giant rebuild — usually a `stdenv` or
`bash` pinning shift.

### Dependency tree

```bash
nix-tree /nix/store/<hash>-package
nix why-depends .#package .#somedep
```

`nix why-depends` shows the path from one closure entry to another — answers
"why is glibc in my closure?"

### Build timing

```bash
time nix build .#package

# What would be built without doing it
nix build --dry-run .#package
```

## Reading the numbers

| Metric | What it means |
|--------|---------------|
| `cpuTime` | Eval CPU ms. Linear with attribute closure size. |
| `nrThunks` | Lazy-eval cells created. Quadratic merges blow this up. |
| `nrEnvs`, `nrValues` | Total allocation counts; high values = lots of intermediate attrs. |
| `gc.totalBytes` | Peak heap before GC. >2 GB indicates a memory leak in eval. |
| Closure size (`du -sh /nix/store/<hash>`) | Runtime size. Watch for unintended dev tools leaking into runtime via `propagatedBuildInputs`. |
