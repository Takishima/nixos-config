# Reference: checking a document, paragraph by paragraph

Used by the `docs` skill's last step and by `preflight` Pass 3.

The frame is [Diátaxis](https://diataxis.fr/): four kinds of documentation, each
serving a different need, each with its own mode of writing. Mixing them is the
most common failure and the one a reviewer flags first — but the most common
*finding* is simply that a paragraph should not be there at all.

## The four quadrants, in their own terms

| Quadrant | Serves | Mode | Title form |
|---|---|---|---|
| **Tutorial** (`docs/tutorials/`) | study — acquiring skill | lesson: *we will* | *Getting started with x* |
| **How-to guide** (`docs/guides/`, `docs/how-to/`, runbooks) | a goal, for someone already competent | recipe: *to achieve w, do z* | *How to integrate x* |
| **Reference** (`docs/reference/`, option descriptions, `--help`) | looking something up | description: *x is, x takes* | the thing's own name |
| **Explanation** (`docs/concepts/`, ADRs, `ARCHITECTURE.md`) | understanding | discussion: *why it is this way* | *About x* |

Establish the quadrant from the path. If the path does not say, take it from the
document's own intro — and if the intro does not say either, that is finding
number one.

A README is not a quadrant. It is the front door that links into them, and its
scope is the README row of the type table in the `docs` skill. A README that has
grown a flag table or a design section is mixing quadrants like any other page:
move those parts out and link them.

### How-to guide

Diátaxis: *"action and only action"*, with *"no digression, explanation,
teaching"*. It addresses *"the already-competent user, whom you can assume to
know what they want to do"*, and *"practical usability is more helpful than
completeness"*. Open with *"This guide shows you how to…"*; title it so the
outcome is explicit (*How to integrate application performance monitoring*, not
*Integrating…*, and never bare *Application performance monitoring*).

Where this project gets caught:

- The intro describes the feature, or how it came to exist, instead of what the
  reader will have achieved by the end. This is the first thing a reviewer
  reads, so it is the first thing they reject.
- Background prose in the middle of a procedure. It reads as noise: a guide is
  goal-oriented, not information-oriented.
- A flag table or field list inside the steps — that is reference. Name the one
  flag the reader needs and link the rest.
- A guide for something that needs no guide, because the command already prints
  what to do. Likewise a section for a workflow that merely *changed*: there is
  no new thing to teach.
- An intro that says nothing on its own and only links onward.
- Details duplicated from a page that already owns them. Link instead.

### Reference

Diátaxis: *"austere and uncompromising"*, demanding *"neutrality, objectivity,
factuality"* and *"accuracy, precision, completeness and clarity"*. **The
structure of the reference mirrors the structure of the product**, so the reader
can navigate both at once. No instruction, no opinion, no recipes — link to
those. Examples illustrate usage without explaining or instructing.

Where this project gets caught:

- The section never establishes what it is reference *for*, which invites the
  question of whether it is needed at all.
- Internal notes filed as reference. They are not reference material: they
  belong in the component's own README, or beside the code they describe.
- Architecture or rationale on a reference page — that is explanation.
- Restating something generic that holds everywhere, or something the page
  already established further up.

### Explanation (including ADRs and `ARCHITECTURE.md`)

Diátaxis: *understanding-oriented*, answering *"Can you tell me about …?"*, and
*"characterised by its distance from the active concerns of the practitioner"*.
It *"can and must consider alternatives"*, including contrary opinions. The
standing risk: *"explanation … tends to absorb other things"*, and *"allowing
them to creep in interferes with the explanation itself, and removes them from
view in the correct place."*

Where this project gets caught:

- Implementation detail in an architecture document. Name the concept; link the
  code or the reference page.
- Content that does not match **the section it sits in**, not just the document:
  motivation under alternatives, a supported workflow listed as a rejected one,
  a prerequisite phrased as an assumption nobody checked. An assumption about
  performance needs a measurement, or it is not an argument.
- An invariant whose name has nothing to do with the reason behind it.
- A decision recorded before the decision was made. Implementation ahead of
  agreement is a process finding, not a docs one — say so and stop.

### Tutorial

Diátaxis: *"A tutorial is not the place for explanation."* *"Ruthlessly minimise
explanation."* *"Ignore options and alternatives"* — the tutorial makes the
choices. *"The first rule of teaching is simply: don't try to teach."* A
document that offers the reader a choice is a how-to guide.

## Per paragraph, in this order

Stop at the first question that answers.

1. **Should it exist?** Does the reader need this, here, at all? By far the most
   frequent verdict on a paragraph in this project is that it is simply
   unnecessary — offered with no further diagnosis, because none is needed. Cut,
   and move on.

1. **Is it documenting around a defect?** A paragraph that exists to warn about
   behaviour which is merely unintuitive is the wrong fix. Change the behaviour;
   if people are still confused after that, then write something.

1. **Is this the quadrant's mode?** Per the sections above. If not: move it to
   the quadrant that owns it, or cut it if that quadrant already covers it.

1. **Does the fact have a closer home?** A name, a type, an option's
   `description`, a doc comment on the thing itself, the component's own README,
   the commit message. An option `description` reaches whoever picks the value; a
   paragraph in a guide reaches only whoever reads the guide. Write it in the
   closer home and cut the paragraph. Same test the project applies to code
   comments — the full rule is in `modules/home/ai-skills/instructions.nix`.

1. **Is it addressed to this document's reader?** One document, one audience. A
   consumer's page does not explain the component's internals; a guide for the
   testing team does not explain the Nix evaluation model. Name the reader, then
   cut what they already know and what they will never need.

1. **Does the document already say it?** Then fix the sentence that says it
   wrong. When a section opens with a claim the change has invalidated, that
   opening is what needs updating — not more documentation added below it.

1. **Is every claim in it checkable?** Undefined referents, numbers no command
   produces, terms of art that cannot be unpacked. Same bar as Pass 1 — a
   sentence that needs its author present is a cost, not content.

Verdict per paragraph: **cut**, **move** (say where), **rewrite** (say what
shrinks), or **keep**.

## Then the document as a whole

- **One name per thing.** Pick the term and unify the synonyms the change
  introduced across the page; a family of near-names for one concept is its own
  finding.
- **No forward references.** Every term a paragraph leans on is defined earlier
  or linked. A term that first appears mid-document with nothing behind it stops
  the reader.
- **The consumer-facing fact goes at the top**, written the way a consumer needs
  it, not buried in a README whose earlier sections are internals.
- **Docs live in the repo.** A workflow documented only on a wiki cannot be
  reviewed and drifts out of sync. If the change implements something whose only
  documentation is a wiki page, that is a finding.
- **Write for humans.** Instructions aimed at an AI tool rather than a
  maintainer are a smell: the code has to stay maintainable by people.
- **Length is a cost.** A shorter section saying the same thing is the better
  patch. Show it.

## Process

Diátaxis is explicit about how to work: *"Diátaxis strongly discourages planning
and top-down workflows, preferring instead small, responsive iterations"*, and
*"every step in the right direction is worth publishing immediately."* So finish
one improvement per document rather than proposing a reorganisation. Do not
create empty quadrant scaffolding.

## Voice

The plain-language rules in the `docs` skill apply to every rewrite. The `prose`
skill carries the AI-tell catalogue and the self-audit prompt (its steps 3a and
3c); run them instead of reinventing the checks.
