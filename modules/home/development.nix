{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.development;
in
{
  imports = [ ./shell.nix ];

  options.my.development = {
    core = lib.mkEnableOption "build and debugging tools (clang, cmake, gdb, valgrind, pre-commit)";
    nix = lib.mkEnableOption "Nix tooling (nixd, nixfmt, statix, nom, nix-tree, devenv, cachix, comma)";
    languages = lib.mkEnableOption "Python, Go, Rust and Node toolchains with their language servers";
    cloud = lib.mkEnableOption "Kubernetes, OpenTofu and sops";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.core {
      home.packages = with pkgs; [
        clang
        clang-tools
        cmake
        cmake-format
        ninja
        meson
        gdb
        valgrind
        perf
        lcov
        pax-utils
        patchelf
        pre-commit
        shellcheck
        shfmt
        neocmakelsp
        bash-language-server
        yaml-language-server
        typos
        typos-lsp
        cloc
      ];

      home.file.".gdbinit".text = ''
        set auto-load local-gdbinit on
        set debuginfod enabled on
      '';

      xdg.configFile."clangd/config.yaml".text = ''
        CompileFlags:
          Add: [-std=c++20, -ferror-limit=0]
        InlayHints:
          Enabled: true
          ParameterNames: true
          DeducedTypes: true
      '';
    })

    (lib.mkIf cfg.nix {
      home.packages = with pkgs; [
        nixd
        nixfmt
        statix
        deadnix
        nixf-diagnose
        dix
        nix-diff
        nix-du
        nix-output-monitor
        nix-tree
        nvd
        nix-update
        nix-fast-build
        nix-eval-jobs
        nix-prefetch-git
        nix-prefetch-github
        cachix
        devenv
      ];

      programs.nix-index.enable = true;
      programs.nix-index-database.comma.enable = true;
    })

    (lib.mkIf cfg.languages {
      home.packages = with pkgs; [
        (python3.withPackages (ps: [
          ps.ipython
          ps.pytest
          ps.python-lsp-server
        ]))
        pyright
        ruff
        ty
        uv

        go
        gopls

        cargo
        rustc
        clippy
        rustfmt
        rust-analyzer

        nodejs_22
        typescript
        typescript-language-server

        taplo
        tree-sitter
      ];

      home.sessionPath = [
        "$HOME/.cargo/bin"
        "$HOME/go/bin"
      ];
    })

    (lib.mkIf cfg.cloud {
      home.packages = with pkgs; [
        kubectl
        kubectx
        k9s
        opentofu
        tflint
        sops
      ];
      my.shell.aliases.k = "kubectl";
    })
  ];
}
