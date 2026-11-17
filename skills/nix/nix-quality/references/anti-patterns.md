# Nix anti-patterns

## Contents

- Critical — eval failures, infinite recursion, non-reproducible builds
- High — performance: slow eval, excess memory
- Moderate — maintainability

Each entry has the pattern, why it's wrong, and the fix.

______________________________________________________________________

## Critical

### Self-referential overlays

```nix
# ❌ Infinite recursion
final: prev: { hello = final.hello.override { }; }

# ✅
final: prev: { hello = prev.hello.override { }; }
```

`final` is the fixpoint *after* all overlays. Referencing the same attribute
you're defining causes Nix to evaluate `final.hello` → which evaluates this
overlay → which evaluates `final.hello` → … Use `prev` for the thing you're
modifying.

### Unquoted URLs

```nix
# ❌ Deprecated; removed in current Nix
url = https://example.com;

# ✅
url = "https://example.com";
```

### Top-level `with` statements

```nix
# ❌ Names appear from nowhere; shadows lexical scope silently
with pkgs; [ curl wget vim ]

# ✅
[ pkgs.curl pkgs.wget pkgs.vim ]
```

`with` inside a let-binding or attribute-set scope is also risky for the same
reason; prefer explicit access.

### `rec` in overlays

```nix
# ❌ pkg-b sees pkg-a as defined here — not overridable
final: prev: rec {
  pkg-a = prev.callPackage ./a { };
  pkg-b = prev.callPackage ./b { dep = pkg-a; };
}

# ✅
final: prev: {
  pkg-a = prev.callPackage ./a { };
  pkg-b = prev.callPackage ./b { dep = final.pkg-a; };
}
```

### External parameters in overlay signature

```nix
# ❌ Not a valid overlay — can't be composed or extended
{ boost }: final: prev: { … }

# ✅
final: prev: {
  myPackage = prev.callPackage ./pkg.nix { boost = final.boost_180; };
}
```

### Unpinned `<nixpkgs>` in production

```nix
# ❌ Non-reproducible
import <nixpkgs> {}

# ✅ Flake
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

# ✅ Non-flake
import (fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/<commit>.tar.gz";
  sha256 = "...";
}) {}
```

Test scripts and one-off `nix repl` sessions are exempt; production
derivations are not.

______________________________________________________________________

## High — performance

### IFD (Import From Derivation)

```nix
# ❌ Blocks evaluation on a build
let generated = pkgs.runCommand "gen" {} ''echo '{ foo = "bar"; }' > $out'';
in import generated

# ✅ Generate at eval time
let generated = builtins.toFile "gen.nix" ''{ foo = "bar"; }'';
in import generated
```

Sometimes IFD is unavoidable (reading a generated lockfile, e.g.
`cargoLock.lockFile`). When it's not avoidable, isolate it to one derivation
and gate the rest of eval on its result.

### Quadratic attribute merges

```nix
# ❌ O(n²) — `//` rebuilds the whole attrset each iteration
lib.foldl (acc: x: acc // { ${x.name} = x; }) {} list

# ✅ O(n log n)
lib.mergeAttrsList (map (x: { ${x.name} = x; }) list)
```

### Thunk explosion in loops

```nix
# ❌ Creates n thunks for the same expensive computation
map (x: let y = expensiveComputation; in x + y) list

# ✅ Compute once
let y = expensiveComputation;
in map (x: x + y) list
```

### Inefficient filtering

```nix
# ❌ Forces evaluation of the entire attrset
builtins.filter (p: !(p.meta.broken or false)) (builtins.attrValues pkgs)

# ✅ Lazy
lib.filterAttrs (name: p: !(p.meta.broken or false)) pkgs
```

### Forcing list length to check emptiness

```nix
# ❌ Evaluates the entire list
if builtins.length list > 0 then ...

# ✅ Lazy
if list != [] then ...
```

______________________________________________________________________

## Moderate — maintainability

### Deep nesting without extraction

```nix
# ❌
config.services.nginx.virtualHosts."example.com".locations."/api".extraConfig = "…";

# ✅
let apiLocation = { proxyPass = "http://localhost:3000"; };
in {
  services.nginx.virtualHosts."example.com".locations."/api" = apiLocation;
}
```

### Magic values without names

```nix
# ❌
if value > 1000 then ...

# ✅
let defaultPriority = 1000;
in if value > defaultPriority then ...
```

### Positional vs named function arguments

```nix
# ❌ What do these mean at the call site?
myFunc = a: b: c: d: ...;

# ✅
myFunc = { a, b, c ? "default", d ? null }: ...;
```

### Inconsistent formatting

Just run `nixfmt`. RFC 166 style (`nixfmt-rfc-style` in nixpkgs) is the
current default.

______________________________________________________________________

## How to find these

`statix check` catches most Moderate-tier issues automatically. Critical and
some High issues need eyeball review or runtime symptoms:

- Infinite recursion → `nix-instantiate --show-trace` and look for the
  attribute path that keeps repeating.
- IFD → eval time spikes for trivial-looking changes; use `nix eval` with
  `--show-trace` and watch for build events during what should be pure eval.
- Quadratic merges → `NIX_SHOW_STATS=1`, watch `nrThunks` grow faster than
  the input list size.
