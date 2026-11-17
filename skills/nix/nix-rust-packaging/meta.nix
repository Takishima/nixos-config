{
  name = "nix-rust-packaging";
  description = "Package Rust crates and applications with Nix: rustPlatform.buildRustPackage, cargoHash vs cargoLock selection, feature flags (buildFeatures / buildNoDefaultFeatures), native -sys crate dependencies (openssl/sqlite/zlib/etc.), cross-compilation, workspace builds, rust-toolchain.toml integration. Use when writing a new Rust derivation, resolving cargoHash / outputHashes mismatches, or wiring -sys C library dependencies.";
  allowedTools = "Read, Write, Edit, Glob, Grep, Bash, WebFetch";
}
