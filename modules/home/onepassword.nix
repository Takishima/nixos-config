{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:
let
  cfg = config.my.onePassword;
  socket = "${config.home.homeDirectory}/.1password/agent.sock";
in
{
  imports = [
    ./git.nix
    ./ssh.nix
  ];

  options.my.onePassword = {
    enable = lib.mkEnableOption "1Password integration" // {
      default = osConfig.my.onePassword.enable or false;
      defaultText = lib.literalExpression "osConfig.my.onePassword.enable";
    };

    agentSocket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = socket;
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables.SSH_AUTH_SOCK = socket;
    # For programs the compositor starts.
    systemd.user.sessionVariables.SSH_AUTH_SOCK = socket;

    programs = {
      ssh.settings."*".IdentityAgent = lib.mkIf config.my.ssh.enable socket;

      git.signing.signer = lib.mkIf (config.my.git.signingKey != null) (
        lib.getExe' (osConfig.programs._1password-gui.package or pkgs._1password-gui) "op-ssh-sign"
      );

      bash.initExtra = ''
        [ -f ~/.config/op/plugins.sh ] && source ~/.config/op/plugins.sh
      '';
      fish.interactiveShellInit = ''
        test -f ~/.config/op/plugins.sh; and source ~/.config/op/plugins.sh
      '';
    };
  };
}
