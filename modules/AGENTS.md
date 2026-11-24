# modules

`flake.nix` exports every entry of `nixos/` and `home/` as a module. So only
modules live there: no helper file, no `AGENTS.md`, no subdirectory that is not
a module. A NixOS module and a home-manager module are not interchangeable.

## Shape of a module

`nixos/audio.nix` is the smallest one, and the one to copy.

- Nothing takes effect until the module's `enable` is set. `nixos/users.nix`,
  `nixos/secrets.nix`, `nixos/nix.nix` and `nixos/locale.nix` are the four that
  always apply.
- One feature per file. The file name is kebab-case, the option camelCase:
  `fan-control.nix`, `my.fanControl`.
- The home part of a feature takes its default from the system part through
  `osConfig`, as `home/onepassword.nix` does.
- A module `imports` the sibling modules whose options it reads or sets:
  `imports = [ ./secrets.nix ];`. An external module it needs goes in the `deps`
  of `modulesIn` in `flake.nix`.
- A module never names `damien`: that belongs in `hosts/` and `home/damien/`.
- A module that bundles others (`vpn-server.nix`) sets them with `lib.mkDefault`
  where a host may disagree.

## Options are the documentation

The `description` says what the option does, what it needs and what happens
without it. That is where a comment about the option belongs.

- `lib.mkEnableOption` for a switch, `lib.mkPackageOption` for a package.
- The narrowest type that fits: `lib.types.port`, `lib.types.enum [ ... ]`.
- `example` when the format is not obvious; `defaultText` when the default is
  computed.
- No option until a host sets it to something other than the default.

## Secrets

A module names its sops keys once, and gates on `config.my.secrets.has "<key>"`.
Without its key it turns the feature off and says so in `warnings`, or fails an
`assertion` when running without it would be unsafe, as `hardened.nix` does.
`duckdns.nix` is the one to copy.

## When you add a module

1. Create `<feature>.nix` in the shape above.
2. Add it to the `imports` of `default.nix` in the same directory, in
   alphabetical order.
3. Turn it on in the host or in `home/damien/`.
4. Add its row to the option table in README.md, and the rows of its sops keys.
5. Add `tests/<feature>.nix` when it opens a port, handles a secret, changes who
   can log in, or runs on a timer: see [tests/AGENTS.md](../tests/AGENTS.md).
