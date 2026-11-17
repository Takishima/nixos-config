{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.claudeCode;
in
{
  options.my.claudeCode = {
    enable = lib.mkEnableOption "Claude Code";
    package = lib.mkPackageOption pkgs "claude-code" {
      extraDescription = "This flake's overlay makes that the llm-agents.nix build.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      inherit (cfg) package;
    };
  };
}
