# Assess Commit History for a Merge Request

Decide whether a branch's commits are **self-contained steps worth keeping**
or **scaffolding to squash**, and recommend one. This is a subroutine:
`create-mr` invokes it to steer the squash-vs-keep decision, but it also runs
standalone.

Keep output to the contract at the bottom — nothing else.

## When to Use

- `create-mr` needs a squash recommendation for a range with more than one commit.
- The user asks "should I squash?", "are my commits clean?", or "is this
  history worth keeping?".

## Input

A target branch to diff against (default: `main`). The caller may pass it.

## What this checks — and what it can't

The project's rule for keeping history is that each commit is a coherent,
self-contained step **and** passes lint/format/tests on its own. You can judge
the first from the diff; you **cannot** verify the second without building each
commit. So assess *cohesion and message quality* and say plainly that
per-commit green is the human's to confirm — don't imply you tested anything.

## Workflow

### Step 1: Read the history

```bash
TARGET="main"  # or caller-supplied

# One commit only → squashing is moot; skip to the contract with SQUASH.
git rev-list --count "$TARGET..HEAD"

# Subject + body + per-commit file stats, oldest first.
git log --reverse --stat --format='%n=== %h %s%n%b' "$TARGET..HEAD"
```

Read a full patch (`git show <sha>`) only for a commit whose cohesion you
genuinely can't call from its message and file list.

**Ground everything in this output — it is your only source.** You may have been
forked with a copy of the caller's context; ignore any description of the branch
from that chatter. If you have not run the commands above in *this* session and
seen their real output, run them now. Your RATIONALE must name only commits and
files that actually appear in the `git log` output — never summarize from memory
or inherited context.

### Step 2: Judge each commit, then the whole

A commit is a **keeper** when it makes one coherent change a reviewer could
read in isolation, with a message that says what and why. It's **scaffolding**
when it is a WIP/checkpoint, a `fixup`/typo/"address review"/"oops" commit, or
mixes unrelated concerns in one blob.

- **KEEP_HISTORY** — every commit is a keeper: the history tells a story worth
  reading commit-by-commit and bisecting later.
- **SQUASH** — one or more commits are scaffolding, or the split is arbitrary.
  The default; when in doubt, squash.

## Output Contract

Emit exactly this block and nothing else, so the caller can parse it:

```
COMMITS_BEGIN
RECOMMENDATION: SQUASH | KEEP_HISTORY
RATIONALE: <one line — for SQUASH, name the scaffolding commits; for KEEP_HISTORY, why the split is worth preserving>
COMMITS_END
```

If the range has no commits, emit exactly:

```
NO_COMMITS
```
