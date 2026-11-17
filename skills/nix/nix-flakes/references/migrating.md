# Migrating to flakes

## When to migrate

| Situation | Migrate? |
|-----------|----------|
| New project | Yes, start with a flake |
| NixOS host configuration | Yes — `nixos-rebuild --flake` is much better UX |
| Reproducibility matters | Yes — `flake.lock` is the whole point |
| Legacy mono-repo with `default.nix` everywhere | Gradual wrapper, don't big-bang |
| One-off script you `nix-build` once | No, leave alone |

## Gradual migration (recommended)

Keep `default.nix` / `shell.nix` working; add a wrapper flake.

```nix
# flake.nix
{
  description = "My project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.default  = pkgs.callPackage ./default.nix { };
      devShells.${system}.default = import ./shell.nix { inherit pkgs; };
    };
}
```

Both interfaces work:

```bash
nix-build && nix-shell          # old
nix build  && nix develop       # new
```

Pin `default.nix` against a stable nixpkgs to match — drop the `<nixpkgs>`
default:

```nix
# default.nix
{ pkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  }) { }
}:
# … rest unchanged
```

## flake-compat back-compat

If users without flakes enabled still need to use the repo, expose
`default.nix` via `flake-compat`:

```nix
# default.nix
(import (fetchTarball {
  url    = "https://github.com/edolstra/flake-compat/archive/master.tar.gz";
  sha256 = "sha256-…";
}) {
  src = ./.;
}).defaultNix
```

This makes `nix-build` and `nix-shell` work against your `flake.nix`. Most
of the time the wrapper-flake approach above is enough; `flake-compat` is
for shops that haven't enabled flakes globally.

## Common breakage at migration time

### `<nixpkgs>` references in derivations

Old `default.nix` often starts:

```nix
{ pkgs ? import <nixpkgs> {} }: …
```

Inside a flake, `<nixpkgs>` resolves via the registry — works locally but
is non-reproducible. Replace with an explicit input:

```nix
# flake.nix passes pkgs in
pkgs.callPackage ./default.nix { }
```

### `builtins.getEnv` / impure paths

Flake eval is **pure** by default. Any `getEnv`, absolute path outside the
flake source, or `NIX_PATH` lookup will fail with `access to absolute path '…' is forbidden in restricted mode`.

Fix: pass the value through an input (e.g. an `inputs.secrets.url = "path:./secrets"`) or expose it as a flake-level `nixpkgs.config` option.

### Lockfile churn

`nix flake update` bumps **every** input. After migrating, run:

```bash
nix flake update              # one-time bump everything
git add flake.lock
git commit -m "Lock dependencies"
```

After that, update one input at a time:

```bash
nix flake update nixpkgs
```

## NixOS configuration migration

Pre-flake:

```bash
sudo nixos-rebuild switch
```

Post-flake — add a `flake.nix` somewhere (often `/etc/nixos/flake.nix`):

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  outputs = { nixpkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
```

Apply: `sudo nixos-rebuild switch --flake /etc/nixos#myhost`.

The existing `configuration.nix` keeps working unchanged unless it used
impure paths (see above).

## Enabling flakes globally

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Or per-command:

```bash
nix --extra-experimental-features 'nix-command flakes' build
```

Anything older than Nix 2.4 doesn't support flakes at all.

## Validation checklist

After migrating, before committing:

- [ ] `nix flake check` passes
- [ ] `nix flake show` lists every expected output
- [ ] `flake.lock` committed
- [ ] Old `nix-build` / `nix-shell` still works (wrapper approach)
- [ ] `nix build .#default` and `nix develop` succeed
- [ ] No `<nixpkgs>` or `builtins.getEnv` remaining in code paths reached
  by flake outputs
