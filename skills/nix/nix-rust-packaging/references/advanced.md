# Advanced Rust packaging

## Workspaces

For a workspace with multiple bins / libs:

```nix
rustPlatform.buildRustPackage {
  pname = "my-workspace";
  version = "1.0.0";
  src = …;

  cargoLock.lockFile = ./Cargo.lock;

  # Build only one workspace member
  cargoBuildFlags = [ "--package" "myapp" ];

  # Or build all (default)
  # buildAndTestSubdir = "myapp";   # alternate: cd into a subdir before building
}
```

To produce multiple bins as separate Nix outputs, the cleanest approach is
to package each member separately, sharing the same `src`:

```nix
let
  src = fetchFromGitHub { … };
  cargoLock = { lockFile = ./Cargo.lock; };
in {
  cli = rustPlatform.buildRustPackage {
    pname = "myworkspace-cli"; version = "1.0.0";
    inherit src cargoLock;
    cargoBuildFlags = [ "--package" "myworkspace-cli" ];
  };

  server = rustPlatform.buildRustPackage {
    pname = "myworkspace-server"; version = "1.0.0";
    inherit src cargoLock;
    cargoBuildFlags = [ "--package" "myworkspace-server" ];
  };
}
```

## Rust toolchain file (`rust-toolchain.toml`)

If upstream pins a specific Rust version via `rust-toolchain.toml`:

```nix
{ rust-bin }:    # from oxalica/rust-overlay

let
  rustToolchain = rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

  rustPlatform = pkgs.makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };
in

rustPlatform.buildRustPackage { … }
```

Needs `oxalica/rust-overlay` (or `nix-community/fenix`) as a flake input.
The default nixpkgs `rustPlatform` uses the system rust which may not match
upstream's MSRV / nightly requirement.

## Git dependencies in Cargo.lock

Cargo allows `git = "…"` deps. Nix can't fetch them anonymously, so each
needs an explicit hash:

```nix
cargoLock = {
  lockFile = ./Cargo.lock;
  outputHashes = {
    "my-git-crate-0.1.0" = "sha256-...";
    "another-git-crate-2.0.0-pre" = "sha256-...";
  };
};
```

Discovery: omit `outputHashes`, build, copy the per-crate hashes from the
"hash mismatch" error block.

## Vendored dependencies (offline build)

For air-gapped builds or auditing:

```bash
cargo vendor
```

Then in the derivation:

```nix
cargoVendorDir = "./vendor";
```

Skips Nix's vendor step entirely. The `vendor/` directory must be part of
`src` and contain all transitive deps.

## `-sys` crate authoring

If *you're* writing a `-sys` crate that wraps a C library, the consumer's
Nix expression needs:

- `pkg-config` in `nativeBuildInputs`.
- The C library in `buildInputs`.
- Possibly `env.YOUR_LIB_NO_VENDOR = "1";` to suppress upstream's bundled
  copy.

In your `build.rs`, use `pkg_config::Config::new().probe("yourlib")` rather
than hardcoded paths — keeps the crate cross-platform and Nix-friendly.

## WASM / wasm32-unknown-unknown

```nix
rustPlatform.buildRustPackage {
  CARGO_BUILD_TARGET = "wasm32-unknown-unknown";

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    wasm-bindgen-cli
  ];

  doCheck = false;     # no host runtime for wasm tests by default
}
```

For `wasm-pack` projects, the build target and post-processing are
different — usually package those via npm tooling, not buildRustPackage.

## `cargo bench` / `cargo check`

```nix
postBuild = ''
  cargo check --workspace --offline
'';

postCheck = ''
  cargo bench --no-run
'';
```

Helpful when CI wants to validate benches still compile even though we
don't want to run them.

## `nightly` toolchain

For crates that require nightly:

```nix
{ rust-bin }:
let
  nightly = rust-bin.nightly.latest.minimal.override {
    extensions = [ "rust-src" "rust-analyzer" ];
  };
  rustPlatform = pkgs.makeRustPlatform {
    cargo = nightly;
    rustc = nightly;
  };
in
rustPlatform.buildRustPackage { … }
```

Pin nightly to a specific date (`rust-bin.nightly."2025-12-01"`) for
reproducibility; "latest" drifts.

## Common pitfalls

- Setting `RUSTFLAGS` via `env.RUSTFLAGS = …` rather than `cargoBuildFlags`.
  RUSTFLAGS is a build-time env var; setting it can clobber per-target
  settings. Prefer `cargoBuildFlags` where possible.
- Forgetting `outputHashes` for git deps — build fails with a non-obvious
  network error inside the vendoring step.
- Using `cargoSha256` (deprecated) instead of `cargoHash`. The two are
  computed identically but `cargoHash` is the SRI-form name expected by
  current nixpkgs.
- Building tests by default for a project that needs network at test time
  → set `doCheck = false;` with a comment explaining which tests required
  net.
