# Overlay performance

Each overlay adds an evaluation pass over its added attributes. Typical
overhead is 10–40% per overlay on the affected attribute closure. The
patterns below cost the most.

## Measure it

```bash
NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH=stats.json \
  nix-instantiate --eval -E '(import ./shell.nix).default'

jq '{ thunks: .nrThunks, cpuMs: .cpuTime, totalBytes: .gc.totalBytes }' stats.json
```

Run twice — once with overlays, once with the overlay list emptied — and
diff the `nrThunks` and `cpuTime` numbers. Anything over a 2× increase is a
red flag.

## Common slow patterns

### `final.callPackage` instead of `prev.callPackage`

```nix
# Slow — re-evaluates through the full overlay chain
final: prev: {
  myPkg = final.callPackage ./pkg.nix { };
}

# Fast
final: prev: {
  myPkg = prev.callPackage ./pkg.nix { };
}
```

Use `final` only for *referencing* dependencies, not for the callPackage call
itself.

### Quadratic attribute merges

```nix
# O(n²) — each `//` rebuilds the whole attrset
lib.foldl (acc: x: acc // { ${x.name} = x; }) {} list

# O(n log n)
lib.mergeAttrsList (map (x: { ${x.name} = x; }) list)
```

### Forcing list length / values eagerly

```nix
# Forces full list evaluation just to check emptiness
if builtins.length list > 0 then ...

# Lazy — pattern match on the cons
if list != [] then ...
```

### Deep `let` inside the overlay body

```nix
# Each call to myPkg re-evaluates `helpers`
final: prev: {
  myPkg = let helpers = expensiveComputation; in
    prev.callPackage ./pkg.nix { inherit helpers; };
}

# Hoist
let helpers = expensiveComputation; in
final: prev: {
  myPkg = prev.callPackage ./pkg.nix { inherit helpers; };
}
```

Note the closure: `helpers` does not depend on `final` / `prev`, so hoisting
is safe and computes it once.

## When in doubt

Add the overlay temporarily, eval the affected package, and compare
`nrThunks` against the baseline. The cost should be proportional to the
number of attributes the overlay touches, not the size of nixpkgs.
