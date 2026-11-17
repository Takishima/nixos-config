{
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  settings.global.excludes = [
    "secrets/*"
    "flake.lock"
    "*.md"
    ".sops.yaml"
    ".gitignore"
  ];
}
