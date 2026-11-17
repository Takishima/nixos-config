# Nix C / C++ packaging

Use this skill when packaging a C or C++ project with Nix —
`stdenv.mkDerivation`, CMake / Meson / Autotools / plain Make, dependency
classification, cross-compilation.

For GPU / CUDA code, jump to `nix-cuda-packaging` instead.

## Skeleton

```nix
{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, openssl
, zlib
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "my-app";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "user";
    repo = finalAttrs.pname;
    rev = "v${finalAttrs.version}";
    hash = "sha256-...";   # placeholder; replace with lib.fakeHash to bootstrap
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs       = [ openssl zlib ];

  meta = {
    description  = "What this thing does";
    homepage     = "https://example.com";
    license      = lib.licenses.mit;
    maintainers  = with lib.maintainers; [ ];
    mainProgram  = "my-app";
  };
})
```

Two non-negotiable choices in the skeleton:

1. **Fixed-point form** — `stdenv.mkDerivation (finalAttrs: { … })` — gives
   you `finalAttrs.pname` / `.version` inside the body and makes
   `.overrideAttrs` work cleanly without `rec`.
1. **`hash = "sha256-…"` not `sha256 = "…"`** — SRI form, mandatory in
   current nixpkgs.

To bootstrap a hash: set `hash = lib.fakeHash;`, build, copy the actual hash
from the error message.

## nativeBuildInputs vs buildInputs

| Goes in | Examples | Rule |
|---------|----------|------|
| `nativeBuildInputs` | cmake, ninja, pkg-config, autoreconfHook, protobuf, bison, flex, makeWrapper, patchelf | Tools that run *during build* on the build host |
| `buildInputs` | openssl, zlib, boost, fmt, spdlog, gtk3 | Libraries linked into the output; available at runtime |
| `propagatedBuildInputs` | header-only libs whose headers leak into downstream | Use sparingly — propagation costs everyone |

Cross-compilation makes the distinction load-bearing. Don't put cmake in
`buildInputs`; don't put openssl in `nativeBuildInputs`.

Platform-specific:

```nix
buildInputs = [ openssl zlib ]
  ++ lib.optionals stdenv.isLinux  [ systemd libseccomp ]
  ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.CoreFoundation
  ];
```

## Build systems

@{context7_tip}### CMake

```nix
nativeBuildInputs = [ cmake ninja ];   # ninja optional, faster than make
cmakeFlags = [
  "-DBUILD_SHARED_LIBS=ON"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DENABLE_TESTS=OFF"
];
```

`cmake` setup hooks handle install, config-file generation, etc.
automatically. `-DCMAKE_BUILD_TYPE=Release` is implied unless `dontStrip` or
debug stdenv; setting it explicitly costs nothing and is clearer.

### Meson

```nix
nativeBuildInputs = [ meson ninja pkg-config ];
mesonFlags = [
  "-Dfeature=enabled"
  "-Dbuildtype=release"
];
```

### Autotools (`./configure`)

```nix
nativeBuildInputs = [
  pkg-config
  autoreconfHook    # only when configure.ac is shipped but `configure` isn't
];
configureFlags = [
  "--enable-feature"
  "--with-openssl=${openssl.dev}"
];
```

`autoreconfHook` re-runs autoconf+automake; skip it if upstream ships a
prebuilt `configure`.

### Plain `make`

```nix
buildInputs = [ zlib ];
dontConfigure = true;
makeFlags = [
  "PREFIX=${placeholder "out"}"
  "CC=${stdenv.cc.targetPrefix}cc"
];
installPhase = ''
  runHook preInstall
  make install PREFIX=$out
  runHook postInstall
'';
```

Always use `${placeholder "out"}` in `makeFlags` — `$out` is only expanded
inside phase scripts.

## Phase customization

The default phases (unpack → patch → configure → build → check → install)
cover most builds. Override sparingly:

```nix
preBuild = ''
  export EXTRA_FLAGS="-fno-strict-aliasing"
'';

postInstall = ''
  mkdir -p $out/share/man/man1
  cp doc/myapp.1 $out/share/man/man1/
  wrapProgram $out/bin/myapp --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
'';
```

`wrapProgram` needs `makeWrapper` in `nativeBuildInputs`.

For multi-output packages, cross-compilation, complex patch handling →
[references/advanced.md](references/advanced.md).

## Testing

```nix
doCheck = true;
checkPhase = ''
  runHook preCheck
  ctest --output-on-failure
  runHook postCheck
'';
```

Skip tests that need network / hardware:

```nix
preCheck = ''
  rm -rf tests/network tests/gpu
'';
```

For cross-builds, `doCheck` is automatically `false` (you can't run target
binaries on the build host). Use `doInstallCheck` for installed-binary
checks that don't depend on architecture.

## Common errors

| Error | First thing to try |
|-------|--------------------|
| `Could NOT find Package` (cmake/pkg-config) | Add the library to `buildInputs`; ensure `pkg-config` is in `nativeBuildInputs` |
| `cannot find -lfoo` at link time | Library missing from `buildInputs`, or it's there but the wrong output (`pkg.dev` for headers, `pkg.lib` for the .so) |
| Builds locally, fails in cross-build | Tool was put in `buildInputs` instead of `nativeBuildInputs` |
| `hash mismatch` on src | Use `lib.fakeHash`, rebuild, copy the actual hash |
| RPATH / runtime missing `.so` | Add to `buildInputs` (so it's linked), or wrap with `--prefix LD_LIBRARY_PATH …` |
| `error: linker command failed` only on Darwin | Missing apple_sdk framework — add to platform-specific `buildInputs` |

## Don't do this

- `stdenv.mkDerivation rec { … }` — use the fixed-point form instead.
- `nativeBuildInputs = [ ]` + dropping cmake in `buildInputs` — works
  natively but breaks cross-compilation.
- `sha256 = "0000…";` — use `hash = "sha256-…";` (SRI form).
- `cmakeFlags = [ "-DCMAKE_INSTALL_PREFIX=$out" ];` — cmake setup hook
  already sets this. Setting it manually fights the hook.
- `makeFlags = [ "PREFIX=$out" ];` — `$out` isn't expanded in attribute
  values. Use `${placeholder "out"}`.

## References

- [references/advanced.md](references/advanced.md) — multi-output
  packages, cross-compilation, complex patch flows, wrappers, fixupPhase.
- For anti-patterns and the validation pipeline see `nix-quality`.
- For overlay-based modifications of an upstream C++ package see
  `nix-overlays`.
