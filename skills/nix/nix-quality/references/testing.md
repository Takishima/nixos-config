# Testing Nix code

## Pure function tests

`lib.runTests` consumes a test attrset and reports mismatches:

```nix
{
  testMyFunction = {
    expr     = myFunction { input = "test"; };
    expected = "expected output";
  };

  testEdgeCase = {
    expr     = myFunction { input = ""; };
    expected = "";
  };

  testError = {
    expr     = builtins.tryEval (myFunction { invalid = "arg"; });
    expected = { success = false; value = false; };
  };
}
```

Run with:

```bash
nix-instantiate --eval --strict -E \
  '(import <nixpkgs> {}).lib.runTests (import ./tests.nix)'
```

Empty list = all passed; any other output is a failure report.

## Integration tests — overlay / module composition

```nix
{
  testOverlayCompose = {
    expr = let
      o1 = final: prev: { test1 = "value1"; };
      o2 = final: prev: { test2 = final.test1 + "-extended"; };
      pkgs = import nixpkgs { overlays = [ o1 o2 ]; };
    in pkgs.test2;
    expected = "value1-extended";
  };
}
```

These also run under `lib.runTests`.

## NixOS VM tests

Real systemd + network in a QEMU VM:

```nix
{
  testMyModule = nixosTest {
    name = "mymodule-test";
    nodes.machine = { ... }: {
      imports = [ ./my-module.nix ];
      services.myservice.enable = true;
    };
    testScript = ''
      machine.wait_for_unit("myservice.service")
      machine.succeed("curl localhost:8080")
    '';
  };
}
```

Run a single test:

```bash
nix build .#checks.x86_64-linux.testMyModule
```

For interactive debugging:

```bash
nix build .#checks.x86_64-linux.testMyModule.driverInteractive
./result/bin/nixos-test-driver
# Inside: machine.shell_interact()
```

## Choosing the level

- **Pure function** test → cheapest, fastest, no sandbox needed. Use for
  lib helpers, mkUser-style factories, option-merging logic.
- **Integration** test (overlay/module composition) → catches type errors
  and missing attribute issues without building anything.
- **NixOS VM** test → only when actual runtime behavior matters. Slow (boots
  a VM) but real.

Don't reach for the heavier tool when the lighter one would catch the bug
class you care about.
