# Functional specs, painlessly

A functional spec describes how a product works **entirely from the user's point of
view**. Features, screens, messages, error cases. It says nothing about data
structures, languages, or algorithms — that's a technical spec, a different document.

The point isn't ceremony. Designing in prose costs a paragraph to change; designing in
code costs a week. The spec is where you get to be wrong cheaply.

Read [references/joel-canon.md](references/joel-canon.md) before drafting your first
spec, or when you need the worked example: it carries the section catalogue with
rationale, the WhatTimeIsIt.com sample-spec walkthrough, and the source links.

## When to write one

| Situation | Do |
|---|---|
| More than ~a week of work, or more than one programmer | Write the spec |
| An architecture / technology decision | An ADR instead — a spec is not an ADR |
| A work item to schedule and assign | The issue tracker — the spec feeds it, doesn't replace it |
| One-line change, obvious behaviour | Skip it, and say so |

## Cover these concerns — this is not a template

Joel's Rule 5 is *avoid templates*: they grow vestigial sections, and an author faced
with empty headings writes filler instead of thinking. So treat the list below as
concerns to have an answer for, not headings to fill. **Delete what doesn't apply.**

- **Disclaimer** — one line saying this spec is not complete. Stops people treating a
  draft as a contract.
- **Author** — exactly one name. Specs by committee read like they were written by a
  committee. Others review; one person decides.
- **Scenarios** — two or three fictitious-but-stereotypical users doing a typical task.
  Named, with irrelevant-seeming biographical detail. This is what makes design
  decisions decidable: you argue about what *Cindy* would do, not about "the user".
- **Non-goals** — a bullet list of what you are deliberately *not* doing. The
  highest-value section per word in the document, and the one people skip.
- **Overview** — the map. A flowchart or a paragraph, so a reader has somewhere to hang
  the details.
- **Details** — the bulk, and the actual product. See below.
- **Open issues** — questions still unresolved, marked inline where they arise. Every
  one must be closed before that part gets coded; a shipped spec with open issues means
  a programmer guessed.
- **Side notes** — tagged asides for one audience: `Technical Note`, `Testing Note`,
  `Marketing Note`, `Documentation Note`. Keeps the main text readable while nothing
  gets lost.

## Details are the spec

Everything else is scaffolding around this section. For each screen, state, or command:

- What the user sees, with a mockup or sample text.
- Every field's limits, defaults, and validation.
- Every error case, **with the exact message text**.
- The unhappy paths: empty state, cancel, back button, double submit, timeout, no
  permission, no network.
- Every policy choice someone would otherwise have to ask about.

Two tests before you call the details done: **could QA write test cases from this
without asking you anything?** and **is there any point where a programmer must guess?**
If either fails, keep writing. This is also why a good spec doubles as the test plan.

## Voice rules

1. **Be funny.** Specs that are boring don't get read, and an unread spec is worth
   nothing. Concrete and absurd beats generic: name a character, pick a ridiculous
   sample value.
1. **Write for a brain to execute.** Big picture before detail. Stories over
   definitions — brains cache narrative and evict abstractions.
1. **Simple as possible.** "Use", not "utilize". Short sentences. Screenshots, bullets,
   whitespace, a pulled-out quote. A wall of text is a wall. The plain-language rules
   in the `docs` skill apply in full; only the humour is specific to specs.
1. **Reread it.** Any sentence that doesn't land on the first pass gets rewritten, not
   defended.

## Anti-patterns

- **Designing in the programming language.** Four weeks building the converter, then
  discovering customers needed something else. Prose iterates in minutes.
- **The frozen spec.** A spec is live until the code is done. Update it as decisions
  change; a stale spec is worse than none because people still trust it.
- **Deferring the hard decisions** while shipping the uncontroversial parts. The spec's
  job is to force the argument now.
- **Implementation leaking in.** If a paragraph would change when you swap databases,
  it belongs in a technical spec or a `Technical Note`.
- **Unfalsifiable requirements.** "The system shall be performant." Give a number or
  cut the line.
- **Requirements-ese.** "The user shall be able to…" for forty pages. Nobody reads it.

## Worth adding beyond Joel

- **Work backwards.** Draft the release note or the user-facing FAQ first. If it doesn't
  sound worth reading, the feature isn't ready to spec.
- **Log the non-obvious decisions** with their rationale, inline. Six months on, "why is
  it like this" costs more than writing the sentence did.
- **Separate reversible from irreversible.** Spend the argument on the doors that only
  open one way; default the rest and move on.

## Workflow

1. **Establish scope.** What's being built, for whom, and what's explicitly out. If
   non-goals are empty, push — an unbounded spec is the failure mode.
1. **Gather what you can't invent.** Use `@{ask_user}` for the decisions only the user
   owns; don't interview them about things you can reasonably default. Ask in small
   groups, not one wall of questions:
   - Who are the two or three users, and what are they actually trying to finish?
   - What's the entry point — how do they arrive?
   - What's out of scope for this release?
   - Which behaviours are already decided, and which are genuinely open?
   - Any hard constraints (platform, existing system, deadline, compliance)?
1. **Draft.** Scenarios first — they expose missing decisions faster than anything else.
   Then non-goals, overview, then grind through the details. Mark every unknown as an
   inline **Open Issue** rather than quietly picking; the open-issue list is the spec's
   real progress bar.
1. **Self-review** against the voice rules and the two details tests above, then present
   for review. Name the open issues explicitly in your handoff.
1. **Maintain.** On later invocations, update the existing spec in place rather than
   writing a second one, and close open issues as they're decided.

When reviewing an existing spec instead of writing one, walk the same concern list and
report what's missing, what's unfalsifiable, and where a programmer would have to guess
— in that order. Missing non-goals and unhandled error cases are the two most common
findings.
