# What every machine of Damien's gets. Each host adds its own file on top.
{
  my = {
    shell.enable = true;

    git = {
      enable = true;
      userName = "Damien Nguyen";
      userEmail = "ngn.damien@gmail.com";
    };

    ssh.enable = true;
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
