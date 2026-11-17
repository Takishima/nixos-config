# NixOS / home-manager modules

Use this skill when declaring new options, writing a service / program
module, composing existing modules, or debugging an option conflict /
priority issue.

For an overlay (modifying nixpkgs packages) the right skill is
`nix-overlays`. For flake plumbing, `nix-flakes`.

## Module shape

Every module is a function returning an attrset with `options` and `config`:

```nix
{ config, lib, pkgs, ... }:

let cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = lib.mkEnableOption "my service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };

    package = lib.mkPackageOption pkgs "myservice" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myservice = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/myservice";
        DynamicUser = true;
      };
    };
  };
}
```

Two non-negotiable rules:

1. **No top-level `with lib;`** — it shadows lexical scope silently. Reach
   for `lib.mkOption`, `lib.types.port`, etc. directly. If repetition gets
   painful, `let inherit (lib) mkOption mkIf types; in …` inside the body.
1. **Options declare, config assigns** — putting `enable = true;` inside
   `options.…` doesn't error, but it doesn't do what you want either.

## Picking a type

| Need | Use |
|------|-----|
| Boolean enable switch | `lib.mkEnableOption "thing"` |
| Package, swappable by user | `lib.mkPackageOption pkgs "name" { }` |
| Port number | `types.port` (not `types.int`) |
| One of a fixed set | `types.enum [ "a" "b" "c" ]` |
| Optional value | `types.nullOr T` |
| List of T | `types.listOf T` |
| Attrset of T | `types.attrsOf T` |
| Structured config | `types.submodule { options = { … }; }` |
| File path | `types.path` |
| Free-form text block | `types.lines` |

For the complete type catalog (ints.between, coercedTo, custom `addCheck`,
submodule-with-name) see [references/types.md](references/types.md).

## Conditional config: `mkIf`, `mkMerge`

```nix
config = lib.mkIf cfg.enable (lib.mkMerge [
  {
    # Base configuration
    systemd.services.myservice = { /* … */ };
  }
  (lib.mkIf cfg.enableMetrics {
    services.prometheus.exporters.myservice.enable = true;
  })
]);
```

`mkMerge` lets you write multiple conditional blocks without nesting
`if-then-else`. The output deep-merges, with conflicts resolved by the
priority system below.

## Priority and overrides

When two modules set the same option, priority decides the winner:

| Call | Priority | Use when |
|------|----------|----------|
| `lib.mkForce x` | 50 | Override stubborn defaults — last resort |
| `lib.mkOverride N x` | N | Custom priority (lower = stronger) |
| plain assignment `= x` | 100 | Default |
| `lib.mkDefault x` | 1000 | "I'd suggest this, but anyone can change it" |

`mkBefore` / `mkAfter` work on lists rather than priorities — they prepend
or append while merging. `mkOrder N` is the general form.

See [references/priority-and-merging.md](references/priority-and-merging.md)
for the full merging algorithm, conflict-resolution flow, and how
submodule defaults interact with parent defaults.

## Submodules

For structured option groups or "many of these" configurations:

```nix
options.services.myservice.instances = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule {
    options = {
      port = lib.mkOption { type = lib.types.port; };
      host = lib.mkOption { type = lib.types.str; default = "localhost"; };
    };
  });
  default = { };
};
```

Users set `services.myservice.instances.foo.port = 8080;` and each sub-attr
gets type-checked.

The submodule function-form gives access to `name` (the attrset key) and
`config` (the sub-config). See
[references/submodules.md](references/submodules.md) for that pattern plus
nested submodules and read-only computed options.

## Module composition

```nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ] ++ lib.optional config.my.desktop.gnome.enable ./gnome.nix;
}
```

To pass extra arguments through to imported modules:

```nix
_module.args = {
  customLib = import ../lib { inherit pkgs; };
};
```

In any imported module, that becomes a function arg:
`{ config, lib, customLib, ... }: …`.

In flake-based setups, `mkUser.nix` (or `mkSystem`) usually owns this — see
the repo's `lib/mkUser.nix` for the pattern in use here.

## Validation

```bash
nix flake check --no-build           # type-check all modules
nix eval .#homeConfigurations.damien.config.services.myservice.port
home-manager build --flake .#damien  # full build, no activation
nixos-rebuild build-vm               # boot a throwaway VM
```

If you hit an option-conflict error:

1. `nix eval` the offending attribute path — Nix prints all loc/priority
   contributors.
1. Decide whether to `mkForce` one side, raise the other to `mkDefault`,
   or split the option into two so both setters can coexist.

For deeper recursion / undefined-variable errors, see `nix-quality` →
`references/debugging.md`.

## Worked example

A complete service module — declare `options.*`, build `config.*`, wire
systemd + user + group + data dir, gate optional features on sub-flags — is
in [references/worked-example.md](references/worked-example.md). Use it as
a template when stamping out a new service module.

## References

- [references/types.md](references/types.md) — full type catalog, including
  composite types and validation helpers.
- [references/submodules.md](references/submodules.md) — submodule patterns,
  the function-form, nested submodules.
- [references/priority-and-merging.md](references/priority-and-merging.md)
  — full priority semantics, list merging, conflict resolution.
- [references/worked-example.md](references/worked-example.md) — a complete
  service module to copy from.

For anti-patterns and validation tooling, see the `nix-quality` skill.
