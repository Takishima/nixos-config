# Rules for a Claude Code cloud session

The `SessionStart` hook in `.claude/settings.json` prints this file when
`CLAUDE_CODE_REMOTE` is `true`: in a session started from the iPhone or iPad
app, or from claude.ai. These rules add to `AGENTS.md`.

- Before committing, run `nix flake check` without asking: nothing else is
  waiting on this machine.
