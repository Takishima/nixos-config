{
  name = "nix-quality";
  description = "Validate and review Nix code: format, lint, dead-code, eval-stat profiling, and the canonical anti-pattern catalog (infinite recursion, IFD, quadratic merges, unpinned nixpkgs, etc.). Use before committing, when diagnosing slow eval, when investigating a recursion / hash / undefined-variable error, or when reviewing a Nix change.";
  allowedTools = "Read, Grep, Glob, Bash, mcp__rime__nix_config_check";
}
