# Summarize Git History for a Merge Request

Turn a branch's commits into a merge-request **title** and a short,
**why-first** description. This is a subroutine: `create-mr` and
`update-mr` invoke it, but it also runs standalone.

Keep output to the contract at the bottom — nothing else.

## When to Use

- A calling skill (`create-mr`, `update-mr`) needs MR content for a range.
- The user asks to "summarize my branch", "draft an MR description from
  my commits", or similar.

## Input

A target branch to diff against (default: `main`). The caller may pass it;
otherwise assume `main`.

## Workflow

### Step 1: Read the history

```bash
TARGET="main"  # or caller-supplied

# Commit subjects + bodies on this branch, oldest first.
git log --reverse --format='%s%n%b' "$TARGET..HEAD"

# Scope of the change — which files/areas, how big.
git diff --stat "$TARGET..HEAD"
```

If the range is empty, emit `NO_COMMITS` and stop.

### Step 2: Distil

Read the commits and the diffstat, then write the contract. The hard part
is restraint — see the rules below.

**Ground everything in Step 1's output — it is your only source.** You may have
been forked with a copy of the caller's context; ignore any description of "what
this branch does" from that chatter. If you have not run the Step 1 commands in
*this* session and seen their real output, run them now. Never summarize from
memory or inherited context.

**Self-check before emitting.** Every file, package, or area you name in TITLE
or CHANGES must literally appear in the `git diff --stat` output. Cross off any
that don't — those are hallucinations. A short diffstat means a narrow summary:
do not inflate two changed files into a sweeping description.

## Output philosophy

The description is for a **reviewer deciding whether to read the diff**, not
a changelog. It complements the commits and changeset; it does not restate
them.

- **WHY first, and short.** One or two sentences, 40 words at the outside, on
  the problem this MR solves or the reason it exists. If the commits already
  make the *what* obvious, the description's job is the *why*.
- **CHANGES = the few points that matter.** At most 4 bullets covering the most
  important changes — the things a reviewer should know before diving in. One
  line each, no sub-bullets, no wrapping into a paragraph. Not one bullet per
  commit. Not a file-by-file tour. If a detail belongs in a commit message,
  leave it there.
- **No bloat.** No "This MR introduces a comprehensive…", no rule-of-three
  padding, no restating the title in prose, no per-file narration. Terse
  and natural. If a bullet doesn't earn its line, cut it.
- **Title** is conventional-commit style, imperative, ≤72 chars
  (`feat(scope): …`, `fix: …`, `refactor: …`). Derive the scope from the
  dominant area in the diffstat.

Litmus test: if a bullet could be reconstructed by reading the commit log,
it probably shouldn't be in CHANGES. Keep what gives a reviewer *context*,
drop what merely *enumerates*.

**Budget: WHY + CHANGES under 120 words together.** Over budget means you are
enumerating, not summarizing — cut bullets rather than shortening every line
into a telegram. A one-bullet CHANGES for a one-idea branch is the right answer,
not a thin one.

## Output Contract

Emit exactly this block and nothing else, so the caller can parse it:

```
SUMMARY_BEGIN
TITLE: <conventional-commit title, imperative, ≤72 chars>
WHY: <1–2 short sentences, ≤40 words: the motivation / problem solved>
CHANGES:
- <most-important change, one line>
- <next most-important change, one line>
(at most 4 bullets; WHY + CHANGES under 120 words total)
SUMMARY_END
```

If there were no commits in the range, emit exactly:

```
NO_COMMITS
```
