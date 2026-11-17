# Nix overlays

Use this skill when adding a package to an existing `pkgs` set, modifying an
upstream package, or composing changes that other overlays / flakes can extend.

## When NOT to use an overlay

- **Single-use tweak in a flake output** → use `pkgs.foo.override { ... }` or
  `pkgs.foo.overrideAttrs (old: { ... })` inline.
- **Defining a brand-new package not tied to nixpkgs** → write the derivation
  directly and use `pkgs.callPackage`.
- **Module-level configuration** → that belongs in a NixOS / home-manager
  module, not an overlay (see `nix-modules`).

## The one rule that matters: `prev` vs `final`

```nix
final: prev: {
  # Modifying an existing package → use prev
  firefox = prev.firefox.override { /* ... */ };

  # Referencing dependencies → use final (lets later overlays substitute them)
  myApp = prev.callPackage ./app.nix {
    libfoo = final.libfoo;
  };
}
```

Mnemonic: **`prev` for the thing being modified, `final` for what it depends
on**. Reaching for `final.X` while *defining* `X` creates infinite recursion.

## Core patterns

### 1. Override an existing package

```nix
final: prev: {
  vim = prev.vim.override { python = final.python3; };
}
```

`.override` changes function arguments. `.overrideAttrs` changes derivation
attributes (patches, version, src, build phases):

```nix
final: prev: {
  firefox = prev.firefox.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./my-patch.patch ];
  });
}
```

### 2. Add a new package

```nix
final: prev: {
  myPackage = prev.callPackage ./my-package.nix {
    libfoo = final.libfoo;   # final → overridable by later overlays
  };
}
```

`prev.callPackage` (not `final.callPackage`) — using `final` here would mean
every later overlay re-evaluates the package, which is wasted work and a
common source of slow evals.

### 3. Scoped overlays (language ecosystems)

Python, Haskell, etc. expose their own override hook:

```nix
final: prev: {
  python3 = prev.python3.override {
    packageOverrides = pyFinal: pyPrev: {
      mylib = pyPrev.buildPythonPackage { /* ... */ };
      requests = pyPrev.requests.overridePythonAttrs (old: { doCheck = false; });
    };
  };
}
```

See [references/scoped-overlays.md](references/scoped-overlays.md) for Haskell,
Rust, Lua variants.

### 4. Compose multiple overlays

Order matters — later overlays see earlier changes:

```nix
pkgs = import nixpkgs {
  inherit system;
  overlays = [ baseOverlay customOverlay overridesOverlay ];
};
```

For more complex composition (file layout, `composeExtensions`,
flake-output integration), see [references/composition.md](references/composition.md).

## What goes wrong

| Symptom | Cause | Fix |
|---------|-------|-----|
| `infinite recursion` while evaluating a package you're modifying | Used `final.X` inside the definition of `X` | Switch to `prev.X` |
| Later overlays can't override a dep | Used `rec` to wire packages together | Drop `rec`; reference via `final` |
| Overlay function takes extra arguments (`{ boost }: final: prev: …`) | Wrong signature — breaks composability | Move the closed-over value into `final` / `prev` |
| Eval time spikes when overlay is added | Likely `final.callPackage` instead of `prev.callPackage`, or deep nested `let` bindings inside the overlay body | See [references/performance.md](references/performance.md) |

For the comprehensive anti-pattern catalog (with severity ratings and
detection commands), see `nix-quality` and its `references/anti-patterns.md`.

## Validation

After editing an overlay:

1. **Format** — `nixfmt <file>` (or `nix fmt`).
1. **Lint** — `statix check <file>`.
1. **Evaluate** — `nix flake check`, or `nix-instantiate --eval --strict <file>`.
1. **Dry-build** the affected package — `nix build --dry-run .#<pkg>`.

If overlay overhead is suspect: `NIX_SHOW_STATS=1 nix eval .#<pkg>` and
inspect `nrThunks` / `cpuTime`.

## Decision: overlay vs `.override` vs flake output

| Use case | Reach for |
|----------|-----------|
| One-off modification, scoped to one flake output | inline `.override` / `.overrideAttrs` |
| Reusable modification used by multiple outputs in this repo | overlay in `overlays/` |
| A modification you want to publish for others | export as `overlays.default` from your flake |
| Brand-new package, no upstream to modify | `callPackage` directly in your flake's `packages.*` |

## References

- [references/scoped-overlays.md](references/scoped-overlays.md) — Python,
  Haskell, Rust, Lua package-set overlays + wrapper/patch patterns.
- [references/composition.md](references/composition.md) — multi-file overlay
  layouts, `composeExtensions`, flake integration.
- [references/performance.md](references/performance.md) — measuring overlay
  overhead, common slow-eval causes.
