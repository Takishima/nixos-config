# For servers: shell, git and SSH, without the larger tools.
{
  imports = [ ./base.nix ];

  my = {
    shell.extras = false;
    git.extras = false;
  };

  programs.nix-index.enable = false;
  manual.manpages.enable = false;
}
