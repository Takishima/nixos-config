# Submodules

## Plain submodule (single instance)

```nix
options.services.myservice = lib.mkOption {
  type = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "myservice";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
      };
    };
  };
  default = { };
};
```

Used to group related options. Users set
`services.myservice = { enable = true; port = 9090; };`.

## `attrsOf submodule` — many instances

```nix
options.services.myservice.instances = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule {
    options = {
      port = lib.mkOption { type = lib.types.port; };
      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
      };
    };
  });
  default = { };
};
```

Users:

```nix
services.myservice.instances = {
  instance1 = { port = 8080; host = "0.0.0.0"; };
  instance2 = { port = 8081; };
};
```

## Function-form submodule

When the submodule needs access to its own attribute name (`name`) or
its sub-config (`config`):

```nix
options.users = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule ({ config, name, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;     # attrset key
      };
      uid = lib.mkOption {
        type = lib.types.int;
      };
      home = lib.mkOption {
        type = lib.types.path;
        default = "/home/${config.name}";
      };
    };
  }));
};
```

`config` here refers to *the submodule's own evaluated config*, not the
outer system config.

## Read-only / computed options

```nix
options.servers = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
    options = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "${name}.example.com";
      };
      url = lib.mkOption {
        type = lib.types.str;
        default = "http://${config.host}";
        readOnly = true;       # downstream cannot set this
      };
    };
  }));
};
```

`readOnly = true` means the option is computed from others and can't be
assigned. Useful for exposing derived values without letting them drift.

## Nested submodules

```nix
options.foo = lib.mkOption {
  type = lib.types.submodule {
    options.bar = lib.mkOption {
      type = lib.types.submodule {
        options.baz = lib.mkOption { type = lib.types.int; };
      };
    };
  };
};
```

Compose. Each level can have its own `default`, `description`, etc. Deep
nesting is fine type-wise but painful to use; consider flattening into a
named sub-attrset once you hit three levels.

## Submodule `freeformType`

When you want type-checked named options plus an open escape hatch:

```nix
options.config = lib.mkOption {
  type = lib.types.submodule {
    freeformType = with lib.types; attrsOf str;
    options.knownOption = lib.mkOption { type = lib.types.int; };
  };
};
```

Anything not declared falls through to `freeformType`. Use sparingly — the
named options give you docs and type checking; the freeform hole gives you
none.

## Pitfalls

- The default value of an option declared *inside* a submodule already has
  `mkDefault` priority. A parent module setting the same field with a plain
  assignment will silently override it. To override an explicit-default
  inner field, use `mkForce` or raise the parent's priority with
  `mkOverride`.
- Submodule defaults are re-evaluated per instance. Avoid expensive
  computation in submodule `default = …` — hoist to a `let`.
- `config` inside the function form is *the submodule's* config, not the
  whole system. To reach the system, use `_module.args` or wire the parent
  via a regular module argument.
