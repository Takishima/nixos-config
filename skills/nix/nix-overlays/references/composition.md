# Overlay composition and organization

## Contents

- Single-file overlay
- Multiple overlays in one directory
- `lib.composeExtensions`
- Flake-exported overlays
- Applying overlays via `import nixpkgs`

## Single-file overlay

For small modifications, a single `overlays/default.nix` is fine:

```nix
# overlays/default.nix
final: prev: {
  myPackage1 = prev.callPackage ./pkgs/pkg1.nix { };
  myPackage2 = prev.callPackage ./pkgs/pkg2.nix { };
}
```

## Multiple overlays, composed

Once the overlay grows past ~50 lines or includes mixed concerns, split it:

```nix
# overlays/default.nix — aggregates child overlays
{
  packages = import ./packages.nix;
  patches  = import ./patches.nix;
  pinned   = import ./pinned.nix;
}
```

```nix
# flake.nix
let overlays = import ./overlays; in {
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      overlays.packages
      overlays.patches
      overlays.pinned
    ];
  };
}
```

Order matters: later overlays see earlier results. Put dependency-defining
overlays first; pinning / version-locking overlays last.

## `lib.composeExtensions`

When you need to programmatically compose two overlays into one:

```nix
combined = lib.composeExtensions overlay1 overlay2;
```

Equivalent to applying `overlay1` then `overlay2`. Useful inside
`packageOverrides` blocks (Python, Haskell) where the `overrides` slot takes a
single function:

```nix
final: prev: {
  haskellPackages = prev.haskellPackages.override (old: {
    overrides = prev.lib.composeExtensions
      (old.overrides or (_: _: {}))
      myHaskellOverlay;
  });
}
```

## Flake-exported overlays

Standard convention:

```nix
# flake.nix
outputs = { self, nixpkgs, ... }: {
  overlays.default = import ./overlays;

  # Or, multiple named overlays
  overlays.packages = import ./overlays/packages.nix;
  overlays.patches  = import ./overlays/patches.nix;
};
```

Downstream consumers:

```nix
inputs.myrepo.url = "github:user/myrepo";

# In their flake
pkgs = import nixpkgs {
  inherit system;
  overlays = [ myrepo.overlays.default ];
};
```

## Applying overlays

Three common application sites:

1. **`import nixpkgs { overlays = [ ... ]; }`** — explicit, most common.
1. **`nixpkgs.overlays = [ ... ];`** in NixOS / home-manager — overlay is
   applied to the system-wide pkgs.
1. **`pkgs.extend overlay`** — apply an overlay to an existing pkgs set
   without re-importing nixpkgs. Cheaper for small ad-hoc additions.

## Don't do this

```nix
# ❌ overlay function takes external arguments
{ boost }: final: prev: {
  myPackage = prev.callPackage ./pkg.nix { inherit boost; };
}
```

An overlay must have the signature `final: prev: { ... }`. External
parameters break `composeExtensions`, prevent the flake registry from loading
it, and prevent downstream `pkgs.extend` calls.

Fix: pin the boost choice inside the overlay (e.g. `boost = final.boost_180;`)
or expose it as a `pkgs.boost` override in a separate overlay applied first.

```nix
# ❌ rec for inter-package references
final: prev: rec {
  pkg-a = prev.callPackage ./a { };
  pkg-b = prev.callPackage ./b { dep = pkg-a; };
}
```

`rec` binds `pkg-a` to the value defined *in this overlay*, so a later
overlay that overrides `pkg-a` won't reach `pkg-b`. Use `final.pkg-a` instead.
