{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.git;
in
{
  options.my.git = {
    enable = lib.mkEnableOption "git with delta, difftastic and mergiraf";

    extras = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to add the tools around git: difftastic, mergiraf, git-absorb,
        git-crypt, git-lfs, gh and glab. Off leaves git with delta.
      '';
    };

    userName = lib.mkOption { type = lib.types.str; };
    userEmail = lib.mkOption { type = lib.types.str; };

    signingKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ssh-ed25519 AAAA...";
      description = ''
        SSH public key commits and tags are signed with. The private half stays
        in the SSH agent; with my.onePassword, 1Password signs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.delta
    ]
    ++ lib.optionals cfg.extras (
      with pkgs;
      [
        difftastic
        mergiraf
        git-absorb
        git-crypt
        gh
        glab
      ]
    );

    programs.git = {
      enable = true;
      lfs.enable = cfg.extras;

      signing = lib.mkIf (cfg.signingKey != null) {
        format = "ssh";
        key = cfg.signingKey;
        signByDefault = true;
      };

      ignores = [
        ".direnv"
        "result"
        "result-*"
        "*~"
        "\\#*\\#"
        ".#*"
        ".DS_Store"
        ".directory"
      ];

      attributes = lib.optional cfg.extras "* merge=mergiraf";

      settings = {
        user = {
          name = cfg.userName;
          email = cfg.userEmail;
        };

        alias = {
          co = "checkout";
          st = "status";
          d = "diff --patience -wb";
          fp = "push --force-with-lease --force-if-includes";
        }
        // lib.optionalAttrs cfg.extras {
          dft = "-c diff.external=difft diff";
          dlog = "-c diff.external=difft log -p --ext-diff";
        };

        gpg.ssh.allowedSignersFile = lib.mkIf (cfg.signingKey != null) (
          toString (pkgs.writeText "allowed_signers" "${cfg.userEmail} ${cfg.signingKey}\n")
        );

        init.defaultBranch = "main";
        core = {
          pager = "delta";
          untrackedcache = true;
        };
        help.autocorrect = "immediate";

        diff = {
          algorithm = "histogram";
          colorMoved = "default";
          mnemonicPrefix = true;
          renames = true;
        }
        // lib.optionalAttrs cfg.extras { tool = "difftastic"; };
        difftool = lib.optionalAttrs cfg.extras {
          prompt = false;
          difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';
        };
        pager.difftool = true;

        merge = {
          conflictStyle = "zdiff3";
        }
        // lib.optionalAttrs cfg.extras {
          mergiraf = {
            name = "mergiraf";
            driver = "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
          };
        };

        interactive.diffFilter = "delta --color-only --features=interactive";
        delta = {
          navigate = true;
          side-by-side = true;
          features = "decorations line-numbers";
          magit-delta.line-numbers = false;
          interactive.keep-plus-minus-markers = false;
          decorations = {
            commit-decoration-style = "blue ol";
            commit-style = "raw";
            hunk-header-decoration-style = "blue box";
            hunk-header-file-style = "red";
            hunk-header-line-number-style = "#067a00";
            hunk-header-style = "file line-number syntax";
          };
        };

        fetch = {
          parallel = 0;
          prune = true;
          pruneTags = true;
          writeCommitGraph = true;
        };
        rerere = {
          enabled = true;
          autoUpdate = true;
        };
        pull.rebase = true;
        rebase = {
          updateRefs = true;
          autoSquash = true;
          autoStash = true;
        };
        push.autoSetupRemote = true;
        tag.sort = "version:refname";
        branch.sort = "-committerdate";
        column.ui = "auto";
      };
    };
  };
}
