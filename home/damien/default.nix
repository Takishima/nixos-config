# Machines Damien works on. Each host adds its own file on top.
{
  imports = [ ./base.nix ];

  my = {
    emacs.enable = true;

    claudeCode.enable = true;
    aiSkills = {
      enable = true;
      roots = [ ../../skills ];
    };
  };

  # Work checkouts keep their own identity.
  programs.git.includes = [
    {
      condition = "gitdir:~/code/hexagon/";
      path = "~/code/hexagon/.gitconfig";
    }
  ];
}
