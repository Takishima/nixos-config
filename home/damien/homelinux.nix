{
  config,
  pkgs,
  ...
}:
let
  keys = {
    inherit (import ./ssh-keys.nix) github;
  };
in
{
  imports = [ ./. ];

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
    terminal.enable = true;

    git.signingKey = keys.github;
    ssh.publicKeys = keys;

    emacs.checkout = "${config.home.homeDirectory}/code/emacs/emacs-config";

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

  programs.ssh.settings."github.com gist.github.com" = {
    User = "git";
    IdentityFile = config.my.ssh.identityFiles.github;
    IdentitiesOnly = true;
  };
}
