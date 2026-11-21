# A Raspberry Pi 4: the shell, git, Claude Code and a terminal Emacs. No
# desktop programs, no compiler toolchains.
{ pkgs, ... }:
{
  imports = [ ./. ];

  home.packages = with pkgs; [
    nixfmt
    nix-output-monitor
  ];

  my.emacs = {
    package = pkgs.emacs-nox;
    # `emacsclient -a ""` starts it on first use, so it holds no memory before.
    daemon.enable = false;
  };

  # The nix-index module turns it on, with a database fetched on every update.
  programs.nix-index.enable = false;

  # Only the tool groups worth their space on the SD card.
  programs.emacs-config.tools = {
    enableAll = false;
    debuggers.enable = false;
    fonts.enable = false;
    search.enable = true;
    vcs.enable = true;
    lsp.enable = true;
    shell.enable = true;
    nix.enable = true;
    json.enable = true;
    yaml.enable = true;
    toml.enable = true;
  };
}
