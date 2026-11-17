# statix.toml Configuration

Place at the repo root. Controls which lints are active project-wide.

```toml
[disabled]
# W20 (repeated_keys) fires on idiomatic flat-attribute module style:
#
#   nixpkgs.config.allowUnfree = true;
#   nixpkgs.hostPlatform = "x86_64-linux";
#
# These are separate NixOS module options that happen to share a prefix,
# not duplicated keys. Disabling this avoids false positives in module
# configurations.
repeated_keys = true

[nix_file_blacklist]
# Add generated, vendored, or documentation-only files that should not
# be linted. Examples:
# "hardware-configuration.nix"
```
