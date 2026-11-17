# prose

Practical writing guide for this repo. Covers commits, MR descriptions,
review comments, blog posts and changelogs, each with its own style.
Documentation (READMEs, guides, reference, explanation) belongs to the
`docs` skill; step 3a and 3c here still apply to it. The pattern catalog and the project's MR template / examples
live in `references/commit-mr-prose.md`; the SKILL body is the
decision matrix and the per-step discipline.

## Quick decision matrix

| Context | Goal | Tone |
|---|---|---|
| **Commit subject** | Survive `git log --oneline` | Imperative present, ~50 chars, `prefix(scope):` if obvious |
| **Commit body** | Explain WHY, not WHAT | Wrap 72, paragraphs over bullets; ticket # if NOT squash-merging |
| **MR description** | Brief for reviewers | MR template, test plan, dependencies, links |
| **Blog posts / changelogs** | Reader is a stranger | AI-tell pass: cut tells, add voice |
| **Documentation** | One reader, one purpose | `docs` skill: plain and neutral, plus the AI-tell pass |
| **Code-review comment** | Move the MR forward | Say WHY, fundamentals first, link blockers to lines |

A trap to avoid: applying "add soul" to a commit subject or a doc.
Commit subjects and documentation are utility prose; "I" and personality
belong in blog posts and MR descriptions, not in `fix(ansible): use inventory_hostname as fallback` or a README.

## Step 1 — Commit message

**Subject**: imperative voice, present tense ("Add foo", not "Added"
/ "Adding" / "Foo added"). ~50 chars, hard ceiling 72. Conventional-
commits prefix (`fix(scope):`, `feat(scope):`, `docs(scope):`,
`refactor:`, `build:`, `chore:`) when one part of the change dominates;
don't force a prefix if no single part dominates. No trailing period.

**Body**: skip it for self-evident changes. Write one when the WHY
isn't obvious from the diff. Priority order:

1. Motivation — what was broken or missing
1. Constraint — what the fix could NOT change (compat, perf, security)
1. Alternative considered — what you tried or rejected, and why
1. Follow-up — debt the change leaves behind

A body that restates the diff is noise.

**Ticket number** in the body — **only when NOT squash-merging**.
Project default IS squash-merge; the MR title + description become the
commit message. When squashing is OFF (commits self-contained, history
worth keeping), put the ticket in each commit body.

**One commit = one decision**. If you write "and" in the subject — split.

Mechanics ([`git rebase -i`, `git commit --fixup`, `git notes`, etc.](references/commit-mr-prose.md#commit-history-mechanics)) are in the
reference — they're invocation-time details, not authoring decisions.

## Step 2 — MR description

Before opening:

- [ ] MR template filled in (ticket URL + test plan)
- [ ] Rebased on `origin/main` (no merge conflicts in the diff)
- [ ] CI green, or your description names what's red and why
- [ ] Azure infra: deployed + verified on staging
- [ ] Dependent MRs listed in metadata
- [ ] Self-review pass — add comments where you want feedback

Description body: WHAT changed, WHY, HOW you tested. The reviewer
should not have to re-derive the motivation.

Keep it to a brief: why in one or two sentences, then at most four one-line
bullets for the changes that matter. A description long enough to scroll gets
skimmed instead of read, and anything a reviewer could get from the commit log
or the diff belongs there, not here.

**Squashing default is ON** (the MR title + description become the
commit message). Turn it OFF when each commit is self-contained and
the history is worth keeping — a deliberately staged refactor, a
release backport with `cherry-pick -x`, or a sequence of independent
ordered steps. Reviewers can then walk the log commit-by-commit; the
description complements the commits instead of replacing them.

\[See `references/commit-mr-prose.md#mr-template` for the template
fields and `#mr-feedback-when-not-actionable` for handling
suggestion-vs-blocker disputes.\]

## Step 3 — Public prose (blog posts, changelogs)

The reader does not have your context. Apply the AI-tell pass: cut the
tells, then check you didn't strip the voice along with them. For
documentation, run 3a and 3c only; 3b does not apply.

### 3a. Cut the tells

Common tells:

- **Em-dash overuse** — substitute commas, periods, or parens
- **Rule of three**: "fast, simple, and powerful" → "fast and simple"
- **AI vocabulary**: `delve`, `tapestry`, `underscore`, `leverage`,
  `crucial`, `seamless`, `vibrant`, `nestled` — use plain words
- **Vague attributions**: "experts believe" / "industry observers" → name them or cut
- **Inflated significance**: "stands as a testament", "pivotal moment"
- **Negative parallelism**: "Not just X, but Y" → say Y directly
- **Sycophantic openers**: "Great question!", "I hope this helps!"
- **Copula avoidance**: "serves as a partner" → "is a partner"

Condensed catalog in
[`references/commit-mr-prose.md#ai-tell-catalog`](references/commit-mr-prose.md#ai-tell-catalog);
full Wikipedia "Signs of AI writing" catalog with before/after examples
in [`references/ai-writing-patterns.md`](references/ai-writing-patterns.md).

### 3b. Keep the voice — sterile is just as obvious

Cutting tells makes prose clean. Clean isn't the goal; "clearly written
by a person" is. Sterile prose reads like a press release: every sentence
the same length, no opinions, no first person where it would fit, no
acknowledgement of mixed feelings.

What to keep:

- **Have opinions.** React to facts, don't just report them. "I keep
  coming back to X" beats neutrally listing pros and cons.
- **Vary rhythm.** Mix short punchy sentences with longer ones that take
  their time. Algorithmic prose is uniform.
- **Acknowledge complexity.** "This is impressive but unsettling" beats
  "this is impressive."
- **Use "I" when it fits.** First person is honest, not unprofessional.
- **Be specific about feelings.** Not "this is concerning" but "there's
  something off about agents churning at 3am while nobody's watching."
- **Let some mess in.** Tangents and half-formed thoughts read as human.

### 3c. Self-audit prompt (catches the last 20%)

After your first revision, ask yourself — verbatim — the question:

> "What makes the below so obviously AI generated?"

Answer in brief bullets (the remaining tells you can name). Then revise
once more against that list. This catches things the catalog misses
because they're rhythm-level, not vocabulary-level: too-tidy contrasts,
slogan closers, plausible-but-fabricated citations, evenly-paced
paragraphs that feel assembled.

A worked example of this loop (input → draft → self-audit → final) is
in
[`references/ai-writing-patterns.md`](references/ai-writing-patterns.md).

## Step 4 — Code-review comments

Priority order:

1. **Be clear.** Async round-trips are expensive.
1. **Say WHY, not just WHAT.** Link the written rule
   (the style guide, an ADR, pre-commit, clang-tidy, ruff). If
   the rule isn't written down, your comment is a suggestion not a
   blocker.
1. **Flag fundamentals before nitpicks.** Design issues first,
   variable names second.
1. **Link blockers to lines of code.** In GitLab, only line-level
   comments block the merge.
1. **Submit all comments together.** Don't drip-feed.

\[Antipatterns to avoid (Tatham + C4): ransom-note, priority-inversion,
guessing-game, flip-flop. Full catalog in
`references/commit-mr-prose.md#reviewer-antipatterns`.\]

When you're the author and a reviewer's comment lacks a written rule
and feels like a value judgment on a working patch, treat it as a
suggestion not a blocker. C4 RFC 42: *"Maintainers SHALL NOT make
value judgments on correct patches."*

## What this skill does NOT cover

- The mechanics of running `git rebase -i`, `git commit --fixup`,
  `git notes` — see `commit-stories` (jylhis-skills-core) for those.
- Conversational tone with the user during a Claude Code session — this
  skill is for written artifacts (commits, MRs, reviews, posts).
- Documentation scope, structure and plain language — see `docs`.

## References

- [`references/commit-mr-prose.md`](references/commit-mr-prose.md) —
  condensed AI-tell catalog, MR template fields, commit-history
  mechanics, reviewer antipatterns, when-feedback-isn't-actionable.
- [`references/ai-writing-patterns.md`](references/ai-writing-patterns.md) —
  full Wikipedia "Signs of AI writing" pattern catalog with before/after
  examples for each pattern. Use for deeper reach on a specific tell;
  the condensed table in `commit-mr-prose.md` is the day-to-day reference.
- Upstream: cbea.ms "How to Write a Git Commit Message", Simon Tatham
  "Code Review Antipatterns", C4 / RFC 42 (ZeroMQ),
  Wikipedia:Signs of AI writing (WikiProject AI Cleanup).
