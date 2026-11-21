{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.emacs;
  emacs = config.programs.emacs-config.finalPackage;
in
{
  imports = [ ./onepassword.nix ];

  options.my.emacs = {
    enable = lib.mkEnableOption "Emacs with the emacs-config flake's configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.emacs-pgtk;
      defaultText = lib.literalExpression "pkgs.emacs-pgtk";
    };

    checkout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice/code/emacs/emacs-config";
      description = ''
        A live checkout to load instead of the input's store copy, so edits
        apply on the next Emacs start. A new package still needs
        `nix flake update emacs-config`.
      '';
    };

    tex = lib.mkEnableOption "TeX Live, texlab and ltex-ls for AUCTeX";

    daemon = {
      enable = lib.mkEnableOption "the Emacs daemon as a user service" // {
        default = true;
      };
      environment = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "LSP_USE_PLISTS=true" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.emacs-config = {
      enable = true;
      inherit (cfg) package checkout;
      treesitGrammars = true;
      manageElispPackages = true;
      # Defaults, so a small machine can pick groups under programs.emacs-config.tools.
      tools = {
        enableAll = lib.mkDefault true;
        tex.enable = cfg.tex;
        debuggers.enable = lib.mkDefault true;
        fonts.enable = lib.mkDefault true;
      };
    };

    home = {
      packages = [ pkgs.emacs-lsp-booster ];
      sessionVariables = {
        EDITOR = "emacsclient -t -a ''";
        VISUAL = "emacsclient -c -a ''";
      };
    };

    systemd.user.services.emacs = lib.mkIf cfg.daemon.enable {
      Unit = {
        Description = "Emacs text editor";
        # A switch must not take the daemon's unsaved buffers with it.
        X-RestartIfChanged = false;
      };
      Service = {
        Type = "notify";
        # A login shell, so the profile's PATH reaches the daemon.
        ExecStart = ''${pkgs.runtimeShell} -l -c "${lib.getExe emacs} --fg-daemon"'';
        SuccessExitStatus = 15;
        Restart = "always";
        Environment =
          cfg.daemon.environment
          ++ lib.optional config.my.onePassword.enable "SSH_AUTH_SOCK=${config.my.onePassword.agentSocket}";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
