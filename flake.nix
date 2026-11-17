{
  description = "NixOS and home-manager configuration for homelinux";

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
      system = "x86_64-linux";
      inherit (nixpkgs) lib;

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

      treefmt = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      nixosConfigurations.homelinux = lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/homelinux ];
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

      packages.${system} = { inherit (pkgs) sops-host ncro; };

      formatter.${system} = treefmt.config.build.wrapper;

      checks.${system} = {
        formatting = treefmt.config.build.check self;
        toplevel = self.nixosConfigurations.homelinux.config.system.build.toplevel;
        statix = pkgs.runCommand "statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
          statix check ${self}
          touch $out
        '';
      };
    };
}
