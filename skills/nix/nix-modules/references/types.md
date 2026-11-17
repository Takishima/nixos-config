# Module types

## Quick lookup

| Type | Range / shape | Example value |
|------|---------------|---------------|
| `types.str` | Any string | `"hello"` |
| `types.nonEmptyStr` | Non-empty | `"config"` |
| `types.int` | Integer | `42` |
| `types.ints.positive` | > 0 | `10` |
| `types.ints.unsigned` | ≥ 0 | `0` |
| `types.ints.between min max` | range | — |
| `types.port` | 0–65535 | `8080` |
| `types.bool` | Boolean | `true` |
| `types.float` | Float | `1.5` |
| `types.path` | Filesystem path | `/var/lib/foo` |
| `types.package` | Nix package | `pkgs.nginx` |
| `types.lines` | Multi-line text (newline-joined when merged) | `"a\nb"` |
| `types.attrs` | Untyped attrset — avoid | `{ … }` |

## Composite types

```nix
types.listOf types.str          # [ "a" "b" ]
types.attrsOf types.int         # { a = 1; b = 2; }
types.nullOr types.str          # null or string
types.either types.str types.int
types.enum [ "small" "medium" "large" ]
```

`types.listOf` deduplicates by default during merging; use
`types.uniq (types.listOf …)` if you want explicit dedup, or
`types.nonEmptyListOf` to require at least one element.

## Validation helpers

```nix
# Range
types.ints.between 0 100

# Type with extra predicate
types.addCheck types.int (x: x >= 0 && x <= 100)

# Coercion (accept str, coerce to int)
types.coercedTo types.str lib.toInt types.port
```

`addCheck` is the escape hatch when the built-in types don't capture your
invariant — keep the predicate side-effect-free and total (don't `throw`
from inside it; return false instead so the merge engine produces a useful
error).

## Submodule type

```nix
options.foo = lib.mkOption {
  type = lib.types.submodule {
    options = {
      bar = lib.mkOption { type = lib.types.str; };
      baz = lib.mkOption { type = lib.types.int; default = 0; };
    };
  };
};
```

Inside the submodule definition you have full access to `lib.mkOption`,
`lib.mkIf`, etc. — it's a normal module fragment.

Function form (gives access to `config`, `name`, `options`):

```nix
options.users = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule ({ config, name, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;          # attrset key
      };
      home = lib.mkOption {
        type = lib.types.path;
        default = "/home/${config.name}";   # cross-option reference
      };
    };
  }));
};
```

## Which type when

- Need a port? Use `types.port`, not `types.int`. Catches `99999`.
- "One of these strings"? Use `types.enum`, not `types.str` + assertion.
- A package the user might want to swap? `lib.mkPackageOption pkgs "name" { }`.
- Free-form key/value config? `types.attrsOf T` where `T` is specific.
  Avoid `types.attrs` — it removes all type checking from the values.
- Untyped escape hatch needed for upstream-defined config? `types.unspecified`
  - a comment explaining why.

## Pitfalls

- `types.attrs` accepts anything and types nothing inside. Prefer a
  submodule.
- `types.lines` joins entries with `"\n"` on merge, which is great for
  things like `extraConfig`; not what you want for arbitrary string fields.
- Mixing `mkDefault` on a submodule field interacts with the submodule's
  own default declaration — the inner `default = x;` is already `mkDefault`
  priority, so a parent setting the same field at default priority wins
  silently. Use `mkForce` or `mkOverride` to override an inner default.
