{
  description = "NixOS and home-manager configuration for homelinux and rpizh";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Only the config home module; niri itself comes from nixpkgs.
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    luciole = {
      url = "github:noctalia-dev/luciole";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    emacs-config = {
      url = "github:takishima/emacs-config";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    ncro = {
      url = "github:manic-systems/ncro";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Not following nixpkgs: it tracks upstream releases daily.
    nix-ai-tools.url = "github:numtide/llm-agents.nix";

  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # { default, <file name> ... }, each importing `deps` beside its file.
      modulesIn =
        dir: deps:
        lib.mapAttrs' (
          file: _:
          lib.nameValuePair (lib.removeSuffix ".nix" file) {
            imports = [
              (dir + "/${file}")
              deps
            ];
          }
        ) (builtins.readDir dir);

      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        }
      );

      treefmtFor = forAllSystems (
        system: (inputs.treefmt-nix.lib.evalModule pkgsFor.${system} ./treefmt.nix).config.build
      );

      rpizh = self.nixosConfigurations.rpizh.config.system.build;
    in
    {
      nixosConfigurations = lib.genAttrs [ "homelinux" "rpizh" ] (
        host:
        lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/${host} ];
        }
      );

      # The Pi under Raspberry Pi OS; under NixOS its home comes with the system.
      homeConfigurations."damien@rpizh" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor.aarch64-linux;
        modules = [
          self.homeModules.default
          ./hosts/rpizh/home.nix
        ];
      };

      overlays = import ./overlays { inherit inputs; };

      # Each module carries what it needs (other modules, external modules, the
      # overlay), so another flake can import one, or `default` for all of them.
      nixosModules = modulesIn ./modules/nixos {
        key = "nixos-config#nixos-deps";
        imports = [
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          inputs.ncro.nixosModules.ncro
        ];
        nixpkgs.overlays = [ self.overlays.default ];
        home-manager.sharedModules = [ self.homeModules.default ];
      };

      # Standalone home-manager also needs overlays.default in its pkgs.
      homeModules = modulesIn ./modules/home {
        key = "nixos-config#home-deps";
        imports = [
          inputs.niri.homeModules.config
          inputs.luciole.homeModules.default
          inputs.emacs-config.homeModules.default
          inputs.nix-index-database.homeModules.nix-index
        ];
      };

      packages = forAllSystems (
        system:
        {
          inherit (pkgsFor.${system}) sops-host ncro;
        }
        // lib.optionalAttrs (system == "aarch64-linux") { rpizh-sd-image = rpizh.sdImage; }
      );

      formatter = forAllSystems (system: treefmtFor.${system}.wrapper);

      checks = {
        x86_64-linux = {
          formatting = treefmtFor.x86_64-linux.check self;
          toplevel = self.nixosConfigurations.homelinux.config.system.build.toplevel;
          statix =
            pkgsFor.x86_64-linux.runCommand "statix" { nativeBuildInputs = [ pkgsFor.x86_64-linux.statix ]; }
              ''
                statix check ${self}
                touch $out
              '';
        };
        aarch64-linux = {
          inherit (rpizh) toplevel;
          home = self.homeConfigurations."damien@rpizh".activationPackage;
        };
      };
    };
}
