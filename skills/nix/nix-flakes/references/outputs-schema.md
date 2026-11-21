# Flake outputs schema

```nix
outputs = { self, nixpkgs, ... }: {
  packages.<system>.<name>    = derivation;
  packages.<system>.default   = derivation;

  devShells.<system>.<name>   = derivation;
  devShells.<system>.default  = derivation;

  apps.<system>.<name>        = { type = "app"; program = "${drv}/bin/x"; };

  nixosConfigurations.<host>    = nixpkgs.lib.nixosSystem { … };
  homeConfigurations.<user>     = home-manager.lib.homeManagerConfiguration { … };

  overlays.default              = final: prev: { … };
  overlays.<name>               = final: prev: { … };

  nixosModules.default          = { config, pkgs, ... }: { … };
  nixosModules.<name>           = …;
  homeManagerModules.<name>     = …;

  lib                            = { myHelper = …; };

  templates.<name>               = { path = ./template; description = "…"; };
  templates.default              = self.templates.<name>;

  formatter.<system>             = pkgs.nixfmt;          # or treefmt, …

  checks.<system>.<name>         = derivation;
};
```

`nix flake show` enumerates all of these. Anything not on the schema is
ignored by the CLI but accessible programmatically via `self.<attr>`.

## Patterns by output type

### Multiple packages, one system

```nix
{
  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          tool1   = pkgs.callPackage ./tool1.nix { };
          tool2   = pkgs.callPackage ./tool2.nix { };
          default = self.packages.${system}.tool1;
        }
      );
    };
}
```

### Multiple dev shells

```nix
{
  outputs = { self, nixpkgs }:
    let forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ]; in {
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.mkShell { buildInputs = with pkgs; [ gcc cmake ]; };

          python = pkgs.mkShell {
            buildInputs = [
              (pkgs.python3.withPackages (ps: with ps; [ pytest requests ]))
            ];
          };

          rust = pkgs.mkShell {
            buildInputs = with pkgs; [ rustc cargo rust-analyzer ];
          };
        }
      );
    };
}
```

User: `nix develop .#python`.

### NixOS configuration

```nix
{
  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.alice = import ./home.nix;
        }
      ];
    };
  };
}
```

Apply: `nixos-rebuild switch --flake .#myhost`.

### Overlay output

```nix
{
  outputs = { self }: {
    overlays.default = final: prev: {
      mypkg = final.callPackage ./mypkg.nix { };
    };

    packages = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system:
      let pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
      in { default = pkgs.mypkg; }
    );
  };
}
```

Downstream consumers can `inputs.you.overlays.default` into their own
pkgs without re-importing your derivation file.

### Templates

```nix
{
  outputs = { self }: {
    templates = {
      python = {
        path = ./templates/python;
        description = "Python project template";
      };
      rust = {
        path = ./templates/rust;
        description = "Rust project template";
      };
      default = self.templates.python;
    };
  };
}
```

User: `nix flake init -t github:you/yourflake#python`.

### Checks

```nix
checks.<system>.test-name = pkgs.runCommand "test-name" { } ''
  echo "running test"; mkdir $out
'';
```

`nix flake check` runs all of `checks.${system}` plus type-checks
`packages`, `devShells`, `nixosConfigurations`, etc.

## Helper libraries

`flake-utils` for cleaner per-system code:

```nix
{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        packages.default = pkgs.hello;
        devShells.default = pkgs.mkShell { };
      }
    );
}
```

`flake-parts` for larger flakes — modular outputs, per-system imports.
Pick one and stick with it across the repo.
