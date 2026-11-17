# Priority and merging

## Priority table

| Call | Numeric priority | When used |
|------|------------------|-----------|
| `lib.mkForce x` | 50 | Force-override even strong setters. Last resort. |
| `lib.mkOverride N x` | N (lower = stronger) | Anything in between — custom priority. |
| plain `= x` | 100 | Default for ordinary assignments. |
| `lib.mkDefault x` | 1000 | "Suggested value, anyone can change." |
| (option's declared default) | 1500 | Implicit; the `default = x;` in `mkOption`. |

Lower number = stronger. Conflicts at the *same* priority that aren't
mergeable produce an error.

## Merging rules

For non-conflicting structural values, Nix merges:

- Attribute sets → recursively merged. Conflicts go to priority resolution.
- Lists → concatenated (modulo `mkBefore` / `mkAfter` / `mkOrder`).
- `types.lines` → joined with `\n`.
- All other scalars → priority resolution; equal priority = error.

## List ordering

```nix
config = {
  services.nginx.appendHttpConfig = lib.mkBefore "# at start";
  services.nginx.appendHttpConfig = lib.mkAfter  "# at end";
  services.nginx.appendHttpConfig = lib.mkOrder 500 "# explicit position";
};
```

Default order priority is 1000 for plain entries; `mkBefore` = 500, `mkAfter`
= 1500. `mkOrder` lets you wedge in between.

Order only matters for sequence-sensitive consumers (nginx configs,
systemd unit `Before=`, etc.). For attrset and most list merges, position
is irrelevant.

## Conflict resolution flow

When two modules assign the same option:

1. Lowest priority wins.

1. If tied: if both values merge structurally (matching attrset shape,
   compatible list types), merge.

1. Otherwise: error like:

   ```
   The option `services.foo.bar' has conflicting definition values:
     - In `<module-a.nix>': "a"
     - In `<module-b.nix>': "b"
   ```

## Diagnosing conflicts

```bash
nix eval .#nixosConfigurations.host.options.services.foo.bar.definitionsWithLocations
```

Returns a list of every setter, their location, and their priority. Most
errors resolve to either:

- Two modules both think they "own" the option → split into separate
  options, or pick one to `mkDefault`.
- A module needs to override another's default but uses the same priority
  → switch to `mkForce` or explicit `mkOverride N` with a stronger N.

## `mkIf` vs priority

`mkIf false x` evaluates to a tombstone that disappears during merging —
*not* a value at low priority. So:

```nix
config = lib.mkIf cfg.enable {
  services.foo = { /* … */ };
};
```

is the right way to conditionally contribute. Don't try to express
"disable" via priority; use `mkIf` for presence/absence and the priority
table for value contention.

## Common patterns

- Library/community module sets sensible default with `mkDefault` →
  end-user config sets a plain `=` to override.
- Two modules both contribute parts of a list → both use plain `=`; they
  concat.
- One module needs to *replace* another's default → use `mkForce` on the
  overriding side. Leaves a footprint that's grep-able later.

## Pitfalls

- A submodule's *inner* `default = x;` is `mkDefault` priority. Parent
  modules assigning the same path with plain `=` win silently. Set the
  parent to `mkForce` if you need the parent's value to lose.
- `mkOverride 0 x` works but is rude. Reserve numeric priorities for cases
  where `mkForce` is too coarse and document why.
- Strings join with `mkBefore` / `mkAfter` only for `types.lines`. Plain
  `types.str` will conflict on overlap.
