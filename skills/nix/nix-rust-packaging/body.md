# Nix Rust packaging

Use this skill when packaging a Rust crate / workspace / application with
Nix — `rustPlatform.buildRustPackage`, `cargoHash` / `cargoLock` choice,
feature flag selection, native-library `-sys` crate dependencies,
cross-compilation.

## Skeleton

```nix
{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, stdenv
, darwin
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname   = "my-rust-app";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "user";
    repo  = finalAttrs.pname;
    rev   = "v${finalAttrs.version}";
    hash  = "sha256-...";
  };

  cargoHash = "sha256-...";

  nativeBuildInputs = [ pkg-config ];
  buildInputs       = [ openssl ]
    ++ lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.Security
      darwin.apple_sdk.frameworks.SystemConfiguration
    ];

  meta = {
    description = "What this thing does";
    homepage    = "https://github.com/user/my-rust-app";
    license     = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "my-rust-app";
  };
})
```

`cargoHash` is the SHA of the vendor directory Nix builds from `Cargo.lock`.

To bootstrap: set `cargoHash = lib.fakeHash;`, build, copy the actual hash
from the error.

## `cargoHash` vs `cargoLock` vs `cargoSha256`

| Option | Use when |
|--------|----------|
| `cargoHash` | Default. Crate is on crates.io; Nix builds a vendor dir from Cargo.lock |
| `cargoLock = { lockFile = ./Cargo.lock; }` | Workspaces / local development; you ship the lockfile separately. Required for git deps |
| `cargoSha256` | **Deprecated.** Don't use in new code |

`cargoHash` and `cargoLock` are mutually exclusive — set one or the other.

For workspaces with git dependencies:

```nix
cargoLock = {
  lockFile = ./Cargo.lock;
  outputHashes = {
    "some-git-dep-0.1.0" = "sha256-...";   # one per git-sourced crate
  };
};
```

Hash discovery: omit `outputHashes`, build, copy the error's per-crate
hashes.

## Feature flags

@{context7_tip}\`\`\`nix

# Enable additional features beyond the defaults

buildFeatures = [ "feature1" "feature2" ];

# Replace default features entirely

buildNoDefaultFeatures = true;
buildFeatures = [ "minimal" ];

````

Common patterns:

- TLS backend selection: `buildFeatures = [ "rustls" ];` (or `native-tls`).
- Trimming for size: `buildNoDefaultFeatures = true; buildFeatures = [ "core" ];`.
- Enabling optional CLI: `buildFeatures = [ "cli" ];`.

`checkFeatures` controls features during test runs separately.

## Native-library dependencies (`-sys` crates)

`-sys` crates wrap C libraries and need the corresponding nixpkgs entry in
`buildInputs`. Cheat sheet:

| crate | needs |
|-------|-------|
| `openssl-sys` | `openssl` + `pkg-config` |
| `libsqlite3-sys` | `sqlite` |
| `libz-sys` | `zlib` |
| `libgit2-sys` | `libgit2` |
| `curl-sys` | `curl` |
| `postgres-sys`, `tokio-postgres` | `postgresql` |
| `mysqlclient-sys` | `libmysqlclient` |
| `libudev-sys` | `udev` (Linux only) |
| `alsa-sys` | `alsa-lib` (Linux only) |
| `freetype-sys` | `freetype` |
| `protobuf-src` | `protobuf` (in `nativeBuildInputs`) |
| `ring` (some configs) | `perl` in `nativeBuildInputs` for asm gen |

Pattern:

```nix
nativeBuildInputs = [
  pkg-config         # almost always for -sys crates
  protobuf           # only if using prost / tonic / protobuf-src
];

buildInputs = [
  openssl
  sqlite
] ++ lib.optionals stdenv.isLinux  [ systemd udev ]
  ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];
````

## Tests

`buildRustPackage` runs `cargo test --release` by default after the build.
Knobs:

```nix
# Disable entirely
doCheck = false;

# Disable on cross-builds (default behavior, explicit here)
doCheck = stdenv.hostPlatform == stdenv.buildPlatform;

# Skip specific tests
checkFlags = [
  "--skip=test_requires_network"
  "--skip=integration::"
];

# Custom check phase
checkPhase = ''
  runHook preCheck
  cargo test --release --workspace -- --skip=ignored
  runHook postCheck
'';
```

## Local development source

When the source is in the current repo (not a fetched archive), use
`lib.fileset` to limit what Nix sees:

```nix
src = lib.fileset.toSource {
  root = ./.;
  fileset = lib.fileset.unions [
    ./Cargo.toml
    ./Cargo.lock
    ./src
    ./benches
    ./build.rs
  ];
};

cargoLock.lockFile = ./Cargo.lock;
```

Excluding `target/`, `.git/`, IDE config etc. keeps the derivation hash
stable across irrelevant changes.

## Cross-compilation

`buildRustPackage` is cross-aware. Rules:

- Build-time tools (`pkg-config`, `protobuf`, `cmake`) → `nativeBuildInputs`.
- Linked / runtime libs → `buildInputs`.
- `doCheck` automatically `false` during cross.

```bash
nix build .#packages.aarch64-linux.my-rust-app
nix build --argstr crossSystem aarch64-linux
```

`-sys` crates with hand-written `build.rs` sometimes need extra hints
(e.g. `OPENSSL_DIR`, `LIBSQLITE3_SYS_USE_PKG_CONFIG=1`). Set via `env.*`:

```nix
env = {
  LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";
  OPENSSL_NO_VENDOR = "1";
};
```

## Common errors

| Error | First thing to try |
|-------|--------------------|
| `failed to run custom build command for openssl-sys` | Add `openssl` to `buildInputs` and `pkg-config` to `nativeBuildInputs` |
| `linker 'cc' not found` | You're cross-compiling; missing toolchain — usually fixed by setting `stdenv.buildPlatform` properly |
| `cargoHash` mismatch | `lib.fakeHash` + rebuild + copy actual |
| `outputHashes` mismatch for a git dep | Look at the error per-crate hash listing; copy each |
| `error: failed to load source for dependency` | Git dep in Cargo.toml but missing `outputHashes` entry |
| OOM during compile | Drop `RUSTFLAGS="-C codegen-units=1"`; use `cargoBuildFlags = [ "--jobs" "2" ];` |
| `cannot find -lssl` at runtime | openssl missing from `buildInputs`, or it's there but `pkg-config` not in `nativeBuildInputs` |

## Don't do this

- `cargoSha256 = "…"` → deprecated, use `cargoHash`.
- `stdenv.mkDerivation` for Rust → use `rustPlatform.buildRustPackage`.
- `cargoHash` *and* `cargoLock` together → pick one.
- `buildInputs = [ rustc cargo ];` → `buildRustPackage` provides the
  toolchain; you don't add it.
- `cargoBuildFlags = [ "--release" ];` → already implied by
  `buildRustPackage`; setting it manually is redundant.

## References

- [references/advanced.md](references/advanced.md) — workspaces with
  multiple bins, `cargo-vendor` workflows, rust-toolchain-file
  integration, FFI / `-sys` crate authoring, WASM targets.
- For overlay-based Rust toolchain swaps see `nix-overlays`.
- For validation tooling see `nix-quality`.
