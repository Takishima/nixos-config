{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.shell;
in
{
  options.my.shell = {
    enable = lib.mkEnableOption "fish, bash, starship, direnv and the CLI toolbelt";

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Aliases for both bash and fish.";
    };
  };

  config = lib.mkIf cfg.enable {
    my.shell.aliases = {
      l = "eza --long --icons --follow-symlinks";
      ll = "eza --long --all --icons --git";
      cat = "bat --paging=never";
      dr = "direnv reload";
      clean-nix = "nh clean all --keep 5 --keep-since 14d";
      nix-show-gc = ''nix-store --gc --print-roots | grep -E -v "^(/nix/var|/run/\w+-system|\{memory|/proc|\{temp:[0-9]+)"'';
    };

    home = {
      shellAliases = cfg.aliases;
      sessionPath = [ "$HOME/.local/bin" ];
      packages = with pkgs; [
        bat
        dust
        eza
        fd
        ripgrep
        jq
        yq-go
        just
        lnav
        tmux
        tree
        unzip
        wget
        whois
        highlight
        tokei
        age
      ];
    };

    xdg.enable = true;

    programs = {
      bash = {
        enable = true;
        historyControl = [
          "erasedups"
          "ignorespace"
        ];
        shellOptions = [
          "histappend"
          "checkwinsize"
        ];
      };

      fish = {
        enable = true;
        interactiveShellInit = ''
          set -g fish_greeting
        '';
      };

      starship = {
        enable = true;
        settings = {
          format = "$hostname$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
          command_timeout = 1000;
          add_newline = false;
          hostname = {
            ssh_only = true;
            format = "[$ssh_symbol$hostname]($style) ";
            style = "bold yellow";
          };
          directory = {
            truncation_length = 3;
            truncate_to_repo = true;
          };
          git_branch.format = "on [$symbol$branch]($style) ";
          git_status = {
            format = "[$all_status$ahead_behind]($style) ";
            conflicted = "=";
            ahead = "⇡$count";
            behind = "⇣$count";
            diverged = "⇕⇡$ahead_count⇣$behind_count";
            untracked = "?$count";
            stashed = "*$count";
            modified = "!$count";
            staged = "+$count";
            deleted = "✘$count";
          };
          nix_shell = {
            format = "via [$symbol$state]($style) ";
            symbol = "❄️ ";
          };
          cmd_duration = {
            min_time = 2000;
            format = "took [$duration]($style) ";
          };
          character = {
            success_symbol = "[❯](bold green)";
            error_symbol = "[❯](bold red)";
          };
        };
      };

      direnv = {
        enable = true;
        nix-direnv.enable = true;
        config.global.hide_env_diff = true;
      };

      fzf.enable = true;
      btop.enable = true;
      zoxide.enable = true;
    };
  };
}
