# Debugging Nix

## Interactive exploration

```bash
nix repl
nix-repl> :l <nixpkgs>          # legacy
nix-repl> :lf .                  # load flake from CWD
nix-repl> :te true               # enable trace
nix-repl> :b pkgs.hello          # build
nix-repl> :e lib.mkBefore        # open source in $EDITOR
nix-repl> :p (someAttr)          # force + pretty-print
```

`:lf` is the fastest way to inspect what a flake exposes — equivalent to
`nix flake show` but interactive.

## Tracing eval errors

```bash
nix-instantiate --eval --show-trace
nix build .#pkg --show-trace
nix build -vvv
nix-instantiate --eval -A package.name --show-trace
```

`--show-trace` is almost always worth turning on once a build fails.

## Hash mismatch recovery

```bash
# Option A — let Nix tell you the hash
nix-prefetch-url https://example.com/file.tar.gz

# Option B — fake-hash trick
fetchurl {
  url = "https://example.com/file.tar.gz";
  hash = lib.fakeHash;     # rebuild; the error message contains the actual
}
```

Same trick works for `cargoHash`, `vendorHash`, `npmDepsHash`, etc.

## Infinite recursion

```
error: infinite recursion encountered
```

1. Run with `--show-trace` and look at the attribute path that repeats.
1. The culprit is almost always one of:
   - `final.X` inside the definition of `X` (overlay).
   - Mutual recursion between modules where `config.foo` reads `config.bar`
     and vice versa.
   - A `let` binding that shadows itself: `let x = x + 1; in x`.
1. Switch the offending reference to `prev.X`, or break the cycle with a
   `mkDefault` to give one side priority.

## "Command not found" at build time

Check which input list the command lives on:

- `nativeBuildInputs` — runs at build time on the build machine
  (cmake, pkg-config, autoreconfHook).
- `buildInputs` — linked at build time, available at runtime
  (openssl, zlib).
- `propagatedBuildInputs` — leaks to consumers of this package. Use
  sparingly.

If the binary exists but the build can't find it, the package's setup-hook
isn't running — usually because it's in `buildInputs` when it should be in
`nativeBuildInputs`.

## Cache issues

```bash
rm -rf ~/.cache/nix              # eval cache
nix-collect-garbage -d           # store GC
nix-store --verify --check-contents
```

Eval cache wipes are safe; store GC will delete anything not GC-rooted (your
home-manager generations, current-system link, etc. are rooted by default).

## Reproducing a failed build

```bash
# Run the failing phase interactively in the build env
nix develop .#pkg
phases="configurePhase buildPhase" genericBuild

# Or open a shell inside the build sandbox
nix-shell -p pkg-config --run 'cd /tmp && unpack-and-cd && bash'
```

For builds that fail only on CI, capture the `result-log` from the CI cache
substituter and compare against a local build's `nix log /nix/store/<drv>`.
