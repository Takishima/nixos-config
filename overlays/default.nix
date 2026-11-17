{ inputs }:
let
  overlays = {
    packages = final: _prev: {
      sops-host = final.callPackage ../pkgs/sops-host.nix { };
    };

    ncro = final: _prev: {
      # shortcut: upstream's package.nix links libsqlite3-sys against a sqlite it never declares.
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
