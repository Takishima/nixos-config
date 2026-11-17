# Scoped overlays — language ecosystems and wrappers

## Contents

- Python package set
- Haskell package set
- Rust / cargo
- Lua / lua5_X
- Wrapper pattern (`symlinkJoin` + `makeWrapper`)
- Patch pattern (`overrideAttrs` + `fetchpatch`)
- Conditional overrides

## Python

```nix
final: prev: {
  python3 = prev.python3.override {
    packageOverrides = pyFinal: pyPrev: {
      mylib = pyPrev.buildPythonPackage {
        pname = "mylib";
        version = "1.0.0";
        src = ./mylib;
      };

      # Disable flaky test in upstream
      requests = pyPrev.requests.overridePythonAttrs (old: {
        doCheck = false;
      });
    };
  };
}
```

The `python3` override is consumed by anything calling `python3.withPackages`
or `python3.pkgs.<name>`. If the repo uses `python311`, override that
attribute name instead — they are independent package sets.

## Haskell

```nix
final: prev: {
  haskellPackages = prev.haskellPackages.override (old: {
    overrides = prev.lib.composeExtensions
      (old.overrides or (_: _: {}))
      (hsFinal: hsPrev: {
        myPackage = hsPrev.callCabal2nix "myPackage" ./. {};
      });
  });
}
```

Composing with `old.overrides` (instead of replacing it) preserves the
upstream nixpkgs Haskell fixes — critical, since nixpkgs ships a large set of
manual overrides for Hackage.

## Rust

Rust crates packaged via `rustPlatform.buildRustPackage` are typically
applied at the package level rather than through a Rust-specific scoped
override. Use a standard overlay:

```nix
final: prev: {
  mytool = prev.rustPlatform.buildRustPackage {
    pname = "mytool";
    version = "0.1.0";
    src = ./.;
    cargoHash = "sha256-...";
  };
}
```

To swap toolchain versions repo-wide, override `rustPlatform`:

```nix
final: prev: {
  rustPlatform = prev.rustPlatform // {
    rust = prev.rust.override { /* ... */ };
  };
}
```

## Lua

```nix
final: prev: {
  lua5_4 = prev.lua5_4.override {
    packageOverrides = luaFinal: luaPrev: {
      mymod = luaPrev.buildLuaPackage { /* ... */ };
    };
  };
}
```

Same pattern as Python — every consumer of `lua5_4.withPackages` sees the
overlay.

## Wrapper pattern

When upstream binary is fine but needs env vars or extra runtime PATH:

```nix
final: prev: {
  myApp = prev.symlinkJoin {
    name = "myapp-wrapped";
    paths = [ prev.myApp ];
    buildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/myapp \
        --set SOME_VAR "value" \
        --prefix PATH : ${prev.lib.makeBinPath [ prev.dependency ]}
    '';
  };
}
```

`symlinkJoin` keeps the closure small (no rebuild of the underlying derivation).

## Patch pattern

```nix
final: prev: {
  package = prev.package.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      (prev.fetchpatch {
        url = "https://example.com/fix.patch";
        hash = "sha256-...";
      })
      ./patches/local-fix.patch
    ];
  });
}
```

Always concat with `(old.patches or [])` — upstream may apply its own patches
that you would otherwise drop.

## Conditional override

When an override only applies under certain conditions (system, package
exists, feature flag):

```nix
final: prev: {
  package =
    if prev ? package then
      prev.package.override { enableFeature = true; }
    else
      prev.package or null;
}
```

Avoid `if final ? package` — it forces evaluation of the final fixpoint at
overlay time, which can deadlock.
