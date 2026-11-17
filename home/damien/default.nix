{
  config,
  pkgs,
  ...
}:
let
  keys = {
    github = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFR+WJj9Kg744PDXXIrmBFbkv7dbetZJSjBbQc1utF1R";
  };
in
{
  home = {
    packages = with pkgs; [
      signal-desktop
      slack
      teams-for-linux
      thunderbird
      libreoffice
      gimp
      vlc
      calibre
      foliate
      speedcrunch
      prusa-slicer
      openscad
      cider-2
    ];
  };

  my = {
    shell.enable = true;
    terminal.enable = true;

    git = {
      enable = true;
      userName = "Damien Nguyen";
      userEmail = "ngn.damien@gmail.com";
      signingKey = keys.github;
    };

    ssh = {
      enable = true;
      publicKeys = keys;
    };

    emacs = {
      enable = true;
      checkout = "${config.home.homeDirectory}/code/emacs/emacs-config";
    };

    development = {
      core = true;
      nix = true;
      languages = true;
      cloud = true;
    };

    spelling = {
      enable = true;
      aspell = [
        "en"
        "fr"
        "de"
      ];
      hunspell = [
        "en_GB-ise"
        "en_US"
        "fr-any"
        "de_CH"
      ];
    };

    cloudSync = {
      onedrive = {
        enable = true;
        accounts.Damien = {
          settings = {
            sync_dir = "${config.home.homeDirectory}/OneDrive";
            check_nosync = "true";
            disable_notifications = "true";
            monitor_log_frequency = "5";
            monitor_fullscan_frequency = "10";
            sync_root_files = "true";
            skip_file = "~*|.~*|*.tmp|*.DS_Store";
          };
          syncList = [ "!/Imports" ];
        };
      };
      synologyDrive.enable = true;
      rclone.enable = true;
    };

    claudeCode.enable = true;
    aiSkills = {
      enable = true;
      roots = [ ../../skills ];
    };

    desktop.niri.outputs = {
      "HDMI-A-1".position = {
        x = 0;
        y = 0;
      };
      "DP-1".position = {
        x = 2560;
        y = 0;
      };
    };
  };

  programs = {
    # Work checkouts keep their own identity.
    git.includes = [
      {
        condition = "gitdir:~/code/hexagon/";
        path = "~/code/hexagon/.gitconfig";
      }
    ];

    ssh.settings."github.com gist.github.com" = {
      User = "git";
      IdentityFile = config.my.ssh.identityFiles.github;
      IdentitiesOnly = true;
    };
  };
}
