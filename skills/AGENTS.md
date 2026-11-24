# skills

The skills are content for agents in other repositories, not instructions for
working on this one: do not follow a skill's body because you opened it here.
The skills that do apply here are the ones `.claude/skills/` names.

## A skill for this repository

`.claude/skills/<name>/SKILL.md` holds the frontmatter and a pointer to
`skills/<area>/<name>/body.md`, with what to skip or read differently here. The
body stays in one place: do not copy it into `.claude/skills/`.

## Shape

- Adding `<area>/<name>/` deploys the skill; there is no list to update.
- The directory name is the name the skill deploys under. Keep `meta.name` equal
  to it; nothing checks that.
- A name is unique across all areas, or an assertion in `ai-skills.nix` fails
  the build.
- `meta.nix` is a plain attribute set. `ai-skills.nix` lists the keys it
  renders (`frontmatter`); a key it does not know is dropped silently, so add
  the key there first.
- A skill with `meta.enable` is not deployed from here.
- `body.md` may use the `@{token}` placeholders listed in `ai-skills.nix`. An
  unknown token is removed from the text.

## Writing a skill

- `description` decides whether the skill is ever loaded. Say what it does, when
  to use it with the words a user would type, and which sibling skill to use
  instead.
- Keep `body.md` to what every use needs. Detail one use in ten needs goes in
  `references/`, linked from the body with the condition for reading it.
- `allowedTools` lists the least that works.
- Markdown here is not formatted by `nix fmt`. Wrap prose at 80 columns.

Check a change evaluates, and lists the skill:

```sh
nix eval .#nixosConfigurations.homelinux.config.home-manager.users.damien.my.aiSkills.names
```
