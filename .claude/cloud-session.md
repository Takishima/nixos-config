# Rules for a Claude Code cloud session

The `SessionStart` hook in `.claude/settings.json` prints this file when
`CLAUDE_CODE_REMOTE` is `true`: in a session started from the iPhone or iPad
app, or from claude.ai. These rules add to `AGENTS.md`.

- Before committing, run `nix flake check` without asking: nothing else is
  waiting on this machine.
- The hook `.claude/hooks/fetch-flake-inputs.sh`, fetches the flake inputs
  in the background, for about a minute, and sends a message when it ends.
  Until then a Nix command fails with HTTP 403 on an input. The hook writes its
  progress and its errors to `~/.cache/fetch-flake-inputs/log`. If the log shows
  no run in progress, run the script and wait for it.
- `NIX_CONFIG` adds the binary caches CI uses, so a build takes from them what
  CI built on `main`. A build of anything else can still fail with HTTP 403 on
  a GitHub tarball: say so, and leave that build to CI.
