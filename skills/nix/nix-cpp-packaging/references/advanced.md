# Advanced C/C++ packaging

## Multi-output packages

Split a package into `bin`, `lib`, `dev`, etc. so downstream consumers
don't pull headers / docs at runtime:

```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "mylib";
  version = "1.2.3";
  src = …;

  outputs = [ "out" "dev" "lib" ];

  nativeBuildInputs = [ cmake ];
  buildInputs = [ zlib ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_INCLUDEDIR=${placeholder "dev"}/include"
    "-DCMAKE_INSTALL_LIBDIR=${placeholder "lib"}/lib"
  ];

  postInstall = ''
    mkdir -p $dev/lib/cmake
    mv $out/lib/cmake $dev/lib/cmake/ || true
  '';
})
```

Conventions:

| Output | Contents |
|--------|----------|
| `out` | Binaries, manpages, default |
| `dev` | Headers, pkg-config files, cmake config files |
| `lib` | Shared libraries (.so / .dylib) |
| `doc` | HTML/PDF documentation |
| `man` | Manual pages |
| `info` | GNU info pages |

`out` is implicit and always present.

## Cross-compilation

The default stdenv is already cross-aware. The only rule: build-time tools
in `nativeBuildInputs`, link-time / runtime libs in `buildInputs`.

```nix
{ stdenv, ... }:

stdenv.mkDerivation {
  …
  nativeBuildInputs = [ cmake pkg-config ];   # runs on build platform
  buildInputs       = [ openssl ];            # for the host platform
}
```

Build for a different target from the command line:

```bash
nix build .#packages.aarch64-linux.myPkg
nix build --argstr crossSystem aarch64-linux
```

If a package uses a runtime helper that's built and immediately executed
(uncommon — codegen tools mostly), it needs to be cross-aware. Reach for
`buildPackages.someTool` to get the build-platform version explicitly.

`doCheck` automatically becomes `false` during cross-builds, since the
target binary can't run on the build host. Use `doInstallCheck` if you have
architecture-independent post-install validation.

## Complex patch workflows

### Local patches

```nix
patches = [
  ./patches/0001-fix-build.patch
  ./patches/0002-bump-cmake.patch
];
```

Applied in order, with `patch -p1` by default.

### Remote patches

```nix
patches = [
  (fetchpatch {
    url    = "https://github.com/foo/bar/commit/abc123.patch";
    hash   = "sha256-...";
    # If the patch needs different strip level:
    stripLen = 2;
    # If the patch was authored against renamed files:
    revert = false;
  })
];
```

`fetchpatch` (not `fetchurl`) for patches because it normalizes the
metadata (removes git-format-patch top-matter) so the hash stays stable
across `git format-patch` version bumps.

### `substituteInPlace`

When a patch would be one line, prefer in-tree substitution:

```nix
postPatch = ''
  substituteInPlace src/config.h \
    --replace '/etc/myapp' "$out/etc/myapp"

  substituteInPlace CMakeLists.txt \
    --replace 'find_package(Boost REQUIRED)' \
              'find_package(Boost ${boost.version} REQUIRED)'
'';
```

Avoids patch-rebase churn when upstream files move.

## Wrappers

When the binary works but needs env / PATH at runtime:

```nix
nativeBuildInputs = [ makeWrapper ];

postFixup = ''
  wrapProgram $out/bin/myapp \
    --prefix PATH : ${lib.makeBinPath [ ffmpeg curl ]} \
    --set MYAPP_DATA_DIR "$out/share/myapp"
'';
```

`postFixup` (not `postInstall`) so the wrap survives the strip / patchelf
phase.

Heavier wrappers — full `symlinkJoin` with multiple binaries — are usually
better done as an overlay than inside the package. See
`nix-overlays/references/scoped-overlays.md` for the wrapper pattern.

## fixupPhase tweaks

```nix
# Don't strip debug symbols
dontStrip = true;

# Don't patch shebang lines
dontPatchShebangs = true;

# Don't run patchelf (rare; usually you want it)
dontPatchELF = true;

# Skip RPATH cleanup
dontAutoPatchelf = true;
```

Each `dont*` flag is a footgun — only use when the package's own logic
already handles the concern (e.g. statically-linked binary doesn't need
patchelf).

## Sandbox issues

If the build needs network access (vendored modules, downloaded fixtures):

```nix
__noChroot = true;     # global access; use only as last resort
# Better:
preBuild = ''
  cp -r ${vendoredDeps} ./vendor
'';
```

Network-during-build flips the build from a derivation to a `fixed-output`
one (must declare the output hash up front, and the build is run with
network). Don't reach for `__noChroot`.

## Common pitfalls

- `find_package(X REQUIRED)` not finding cmake config files → check
  `<pkg>.dev` is in `buildInputs` and contains `lib/cmake/X/XConfig.cmake`.
- `dlopen("libfoo.so")` at runtime can't find lib → it's not in RPATH;
  needs to be in `buildInputs` so patchelf knows about it.
- Tests that pass `localhost:N` networking → `__noChroot = true;` to allow
  the loopback, or skip those tests.
- Build picks up wrong compiler version → check `stdenv.cc.cc.version`;
  override stdenv (`override { stdenv = pkgs.gcc12Stdenv; }`) if needed.
