# Nix flakes

Use this skill when starting a new flake, editing `flake.nix` (inputs,
outputs, dev shells, NixOS configurations), updating `flake.lock`, or
migrating an existing `default.nix` / `shell.nix` to flakes.

## Minimal shape

```nix
{
  description = "What this flake provides";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.callPackage ./default.nix { };
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          buildInputs = with nixpkgs.legacyPackages.${system}; [ gcc cmake ];
        };
      });
    };
}
```

Notes:

- `legacyPackages.${system}` is the standard accessor for a system's pkgs.
  No `import nixpkgs { }` plumbing needed.
- `forAllSystems` (or `flake-utils.eachDefaultSystem`) avoids repeating the
  same code for every supported platform.
- `default` output is what `nix build` / `nix develop` pick when no
  attribute is specified — always provide one.

## Inputs

@{context7_tip}### From GitHub / GitLab

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  myrepo.url  = "github:user/repo";
  myrepo.url  = "github:user/repo/branch-or-tag-or-sha";

  gitlabthing.url = "gitlab:group/project";
};
```

### Same-`nixpkgs` discipline with `follows`

Without `follows`, every input that depends on `nixpkgs` brings its *own*
nixpkgs into your closure. Pin everything to your `nixpkgs`:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  tool = {
    url = "github:user/tool";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };
};
```

Other input forms (git, path, tarball + narHash) → see
[references/input-recipes.md](references/input-recipes.md).

## Outputs schema

Standard top-level attributes the flake CLI knows about:

| Attribute | Purpose |
|-----------|---------|
| `packages.<system>.<name>` | Buildable derivation (`nix build .#name`) |
| `devShells.<system>.<name>` | Dev environment (`nix develop .#name`) |
| `nixosConfigurations.<host>` | NixOS system (`nixos-rebuild switch --flake .#host`) |
| `homeConfigurations.<user>` | Home-Manager config (`home-manager switch --flake .#user`) |
| `overlays.default` / `overlays.<n>` | Nixpkgs overlays for downstream use |
| `nixosModules.default` / `<n>` | Reusable NixOS modules |
| `apps.<system>.<n>` | Runnable (`nix run .#n`) |
| `checks.<system>.<n>` | CI / `nix flake check` |
| `formatter.<system>` | What `nix fmt` runs |
| `templates.<n>` | `nix flake init -t .#n` scaffolds |
| `lib` | Plain Nix library functions |

Full attribute layout + advanced examples → see
[references/outputs-schema.md](references/outputs-schema.md).

## Commands worth knowing

```bash
# Inspect
nix flake show              # all outputs
nix flake metadata          # pinned revs, paths
nix flake check             # eval + run checks

# Build / run
nix build .#pkg
nix develop .#shell
nix run .#app

# Lock-file management
nix flake update                                # bump all inputs
nix flake update nixpkgs                        # bump one input
nix build --override-input nixpkgs <url>        # one-off, no lock change

# Init
nix flake init -t templates#python
```

`flake.lock` **must** be committed. It's the reproducibility contract.

## Migrating from non-flakes

If you have a working `default.nix` and `shell.nix`, the cheap migration
is a wrapper flake — no need to rewrite the existing files:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.default = pkgs.callPackage ./default.nix { };
      devShells.${system}.default = import ./shell.nix { inherit pkgs; };
    };
}
```

Both `nix build` (new) and `nix-build` (old) keep working. Full migration
checklist + flake-compat back-compat → see
[references/migrating.md](references/migrating.md).

## NixOS / home-manager from a flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };

    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home.nix ];
    };
  };
}
```

This repo's `lib/mkUser.nix` wraps `homeManagerConfiguration` to share
overlays and special args across all users — look there for the local pattern.

## Common errors

| Error | First thing to try |
|-------|--------------------|
| `Path is not a flake` | You're in a non-flake dir — `cd` to the flake root, or pass the path explicitly: `nix build /path/to/flake#pkg` |
| `getting status of ... no such file` | Untracked file referenced; `git add` it (flake source = committed tree) |
| Lock file conflict on `nix flake update` | Resolve manually like any merge; `flake.lock` is JSON, hand-edit is fine for narrow conflicts |
| `error: experimental Nix feature 'nix-command' is disabled` | Add `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf` |

Deeper recursion / eval failures → `nix-quality` →
`references/debugging.md`.

## Don't do this

- Put environment variables (`builtins.getEnv …`) inside `outputs`. That
  makes evaluation impure and breaks the lock.
- IFD on inputs (e.g. `inputs.x.url = "path:${import ./gen.nix}";`). Inputs
  must be static.
- Add `flake.lock` to `.gitignore`. It is the lock; it must be committed.
- Run `nix flake update` casually right before a release — it can bump every
  transitive input. Update one input at a time (`nix flake update nixpkgs`).

## References

- [references/input-recipes.md](references/input-recipes.md) — every input
  URL form (github/gitlab/git+ssh/path/tarball/registry), private-repo
  auth, narHash pinning.
- [references/outputs-schema.md](references/outputs-schema.md) — full
  schema with examples per output type.
- [references/migrating.md](references/migrating.md) — gradual migration
  recipe, flake-compat wrapper, breaking-change pitfalls.

For anti-patterns and validation, see `nix-quality`. For
NixOS / home-manager modules consumed by flake outputs, see `nix-modules`.
