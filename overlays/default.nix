# The flake's overlays, and `default`, which applies them all.
{ inputs }:
let
  overlays = {
    packages = final: _prev: {
      sops-host = final.callPackage ../pkgs/sops-host.nix { };
    };

    homebridge = final: _prev: {
      homebridge-miot = final.callPackage ../pkgs/homebridge-miot { };
      homebridge-password-hash = final.callPackage ../pkgs/homebridge-password-hash.nix { };
      homebridge-synology = final.callPackage ../pkgs/homebridge-synology { };
    };

    ncro = final: _prev: {
      # Upstream's package.nix links libsqlite3-sys against a sqlite it does not declare.
      ncro = (final.callPackage "${inputs.ncro}/nix/package.nix" { }).overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ final.sqlite ];
      });
    };

    # The llm-agents.nix build instead of nixpkgs'.
    claude-code = final: _prev: {
      inherit (inputs.nix-ai-tools.packages.${final.stdenv.hostPlatform.system}) claude-code;
    };
  };
in
overlays
// {
  default =
    final: prev: builtins.foldl' (acc: o: acc // o final prev) { } (builtins.attrValues overlays);
}
