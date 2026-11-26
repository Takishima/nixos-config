# nixos-config

Read [README.md](README.md) first: it has the layout, the options, the sops keys
and the commands, and nothing here repeats it. This file holds the rules for
changing the code. A directory with its own `AGENTS.md` adds the rules for its
subtree.

## Where things go

These paths have rules of their own:

| Path | Read before you change it |
| --- | --- |
| `modules/` | [modules/AGENTS.md](modules/AGENTS.md) |
| `hosts/`, `home/damien/` | [hosts/AGENTS.md](hosts/AGENTS.md) |
| `tests/` | [tests/AGENTS.md](tests/AGENTS.md) |
| `skills/` | [skills/AGENTS.md](skills/AGENTS.md) |
| `.claude/skills/` | [skills/AGENTS.md](skills/AGENTS.md), "A skill for this repository" |
| `README.md`, `docs/`, any `AGENTS.md` | [Documentation](#documentation) below |
| `secrets/` | [Secrets](#secrets) below: not yours to edit |

- A package is called with `callPackage` from `overlays/default.nix`, or from
  `flake.nix` when it takes a host's settings.
- `flake.nix` discovers hosts, modules, tests and skills from their directories.
  A file in the wrong place becomes a host, a module or a check.
- A flake only sees files git tracks: `git add` a new file before you evaluate.

## Names carry the meaning

- Pick expressive, self-documenting names: `withPassword`, `recipientsOf`,
  `neverBan`. A name that needs a comment is the wrong name.
- Prefer refactoring over commenting. Bind the unclear expression to a named
  `let`, or split the function, before you explain it.

## Comments: find the fact's home first

Before writing a comment, look for the fact's canonical home. If it has one,
write it there:

| The fact | Its home |
| --- | --- |
| What a value is | Its name |
| What a value may hold | Its type: `lib.types.*`, an `assertion` |
| What an option does, and what it needs | The option's `description`, or the `mkEnableOption` text |
| Why the change was made | The commit message |
| How a called function behaves | That function's own documentation |
| How a person uses the feature | `README.md` or `docs/` |

- Write for a reader who has not made your mistake. A note recording a wrong
  turn you took charges every later reader for it.
- Two lines is the ceiling. Past that, change the code, or keep the comment
  short and give the reason in the commit message. The commit message carries
  the worked example: the command, the error, the measurement.
- A comment never restates the code, the attribute name, or history.

What is left for a comment: one line at the top of a file saying what it is, and
a reason the code cannot show, such as `# ath12k (WCN785x) needs a recent kernel.`

## Add only what the change needs

No dead or commented-out code, no unused bindings, no attribute set to its
default, no option nobody sets. Nothing "just in case".

## Fix the problem at its source

- Fix the module or package that owns the problem, not the host where it shows.
- Before working around an input, check whether a newer revision has the fix:
  `nix flake update <input>`.
- Change source with a `.patch` file or `fetchpatch2`, never `sed` in a build
  phase. A patch fails loudly once it stops applying.

## Reuse before you write

Check nixpkgs `lib` ([noogle.dev](https://noogle.dev)), the NixOS and
home-manager options, and the modules here first.

| Instead of | Use |
| --- | --- |
| `"${pkg}/bin/foo"` or a PATH lookup | `lib.getExe pkg` |
| `writeScript` or `runCommand` for a script | `writeShellApplication`, which runs shellcheck |
| `builtins.trace` | `warnings`, `assertions`, `lib.warn` |
| `rec { }` | `let ... in` |
| A second `import nixpkgs` | `pkgsFor` in `flake.nix`, `pkgs` in a module |
| A value copied from another module | `config.<its option>` |
| A hand-written `package` option | `lib.mkPackageOption` |

- A new flake input follows `nixpkgs`, unless a comment says why it cannot.
- Fail loudly: `throw`, an `assertion` or a `warning`, never `|| true` or a
  silent filter.

## Secrets

- You do not have the keys `secrets/*.yaml` are encrypted for. Do not edit the
  files; name the sops key the user has to add, and add its row to the table in
  README.md, "Secrets".
- No plaintext secret, token or private key goes into the repository, a test or
  a commit message. Tests use nixpkgs' throwaway keys and `tests/fixtures`.

## Documentation

Before writing, finish this sentence: "This is a \<type> for \<reader>, who
wants to \<goal>." Content that needs two such sentences is two documents.

| Document | The reader wants to | It holds | It does not hold |
| --- | --- | --- | --- |
| `README.md` | Decide whether this is for them, then start | What the flake is, the layout, one row per option, output and sops key, the commands | Steps longer than a few commands, design history, what an option `description` already says |
| A guide, `docs/<task>.md`, titled "How to ..." | Reach a goal they already know | Prerequisites, numbered steps, the one option each step needs | Background, every option, how it came to be |
| An explanation, `docs/<subject>.md`, titled "About ..." | Understand why it is this way | Context, trade-offs, what is trusted and refused | Steps, option lists |
| An option's `description` | Pick a value now | What it does, what the default means, what it needs | History, implementation |
| `AGENTS.md` | Work in the repository as an agent | What the code and the README cannot tell: conventions, traps | Anything a README, `docs/` or the code already says. Link to it |
| Commit message | Know why the code changed | The reason, the command, the error, the measurement | A list of what the diff shows |

Then write it in plain language:

- Common words: *use*, not *utilize*. One name per thing, the option's own.
- Short sentences, one idea each. Active voice, with the actor named: "The
  module writes `/etc/nix/netrc`", not "`/etc/nix/netrc` is written".
- The point first. A condition comes before its action: "If the build fails,
  run ...".
- Real commands, paths and values. An example beats a paragraph.
- Numbered lists for steps, tables to compare, sentences for reasons. No bullet
  list where one sentence does.
- No filler (*simply*, *just*, *note that*), no intro that previews the page, no
  summary that repeats it. No first person, no opinions.
- No AI tells: chains of em dashes, lists of three for rhythm, "not just X but
  Y", bold scattered for emphasis.

Then cut. Ask of each paragraph, and stop at the first answer:

1. Would the reader miss it? If not, cut it.
2. Does the command, its output or its error already say it? Cut it.
3. Does the fact have a closer home, per the table under
   [Comments](#comments-find-the-facts-home-first)? Write it there.
4. Does another document already say it? Link to it.

- Fix a stale sentence. Do not add a correction under it.
- Do not document around a defect: fix the behaviour.
- Between two versions that say the same, ship the shorter one.
- A README table gets one row per thing. The detail goes in the option's
  `description` or in `docs/`.
- Finish one improvement. Do not propose a new doc tree, and do not create a
  page with nothing to put in it.
- Markdown is not formatted by `nix fmt`. Wrap prose at 80 columns, as the README
  does.

The `docs` and `prose` skills in `.claude/skills/` hold these rules in full,
with the failures per kind of document. Use `docs` before a larger documentation
change.

## Commits

- `type(scope): subject`, as in `git log`: `feat`, `fix`, `refactor`, `docs`,
  `chore`, `ci`. The scope is the module or host: `feat(wireguard): ...`.
- Subject imperative, lower case, 72 characters or fewer.
- The body is a short paragraph saying why. The diff already says what.
- One concern per commit. A refactor goes apart from the change it prepares.
- A change to an option, an output, a sops key or a command updates its row in
  README.md, and the steps in `docs/` that use it, in the same commit.

## Check before committing

1. `nix fmt` changes nothing.
2. `nix build .#checks.x86_64-linux.statix` passes.
3. Every host you could have affected still evaluates:
   `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.
   A module change can affect all three.
4. A changed module with a test in `tests/`: say which `vm-<name>` check covers
   it. Run it if KVM is there; otherwise say CI will.
5. `git diff --cached -U0 -- '*.nix' | grep -E '^\+\s*#'`: every hit passes the
   comment rules above.
6. `git log --format=%s origin/main..HEAD | awk 'length > 72'` prints nothing.

`nix flake check` runs all of the above and more. Leave it to CI unless the
user asks.

## Rules for one kind of session

A rule that holds only in a Claude Code cloud session, such as one started from
the iPhone or iPad app, goes in
[.claude/cloud-session.md](.claude/cloud-session.md), not here. The
`SessionStart` hook in `.claude/settings.json` loads that file in those sessions
only.

## Scope and precedence

These rules govern code you add or rewrite. Editing a file does not oblige you
to clean up lines you did not touch. A scoped `AGENTS.md` wins inside its
subtree, and an explicit instruction in the task outranks both. On a conflict,
stop and report.
