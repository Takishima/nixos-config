# Painless Functional Specifications — the source method

Condensed from Joel Spolsky's four-part series (October 2000) plus his sample spec.
Read this when you need the reasoning behind a rule, or a concrete example of the voice.

- [Part 1 — Why Bother?](https://www.joelonsoftware.com/2000/10/02/painless-functional-specifications-part-1-why-bother/)
- [Part 2 — What's a Spec?](https://www.joelonsoftware.com/2000/10/03/painless-functional-specifications-part-2-whats-a-spec/)
- [Part 3 — But… How?](https://www.joelonsoftware.com/2000/10/04/painless-functional-specifications-part-3-but-how/)
- [Part 4 — Tips](https://www.joelonsoftware.com/2000/10/15/painless-functional-specifications-part-4-tips/)
- [Sample spec — WhatTimeIsIt.com](https://www.joelonsoftware.com/whattimeisit/)

## Part 1 — why bother

Failing to write a spec is "the single biggest unnecessary risk" a software project
takes. Four arguments:

**Design.** The Speedy vs Mr. Rogers story: Speedy skips the spec and codes for four
weeks, including a backwards-compatibility converter, then learns customers needed a
different approach — sunk. Mr. Rogers writes a spec, iterates the design in a word
processor, and finishes the whole thing in just over three weeks. Iterating a design in
code costs weeks per pass; deleting a paragraph costs nothing.

**Communication.** Without a spec, the design lives only in the programmers' heads, so
every question routes through them. QA interrupts constantly to ask what the intended
behaviour was. Technical writers can't start. Marketing invents its own version. The
spec is the single source of truth that lets everyone work in parallel.

**Scheduling.** You cannot estimate work you haven't described. No spec, no schedule.

**Finality.** Specs force contentious decisions to be made *now*, instead of letting the
team ship the easy parts and leave the argument for month five.

The stated reason people skip specs — "it saves time" — is false. The real reason is that
writing is uncomfortable. The fix is practice, not avoidance.

## Part 2 — what a spec is

**Functional spec:** how the product works from the user's perspective. Features,
screens, behaviours. Says nothing about implementation.

**Technical spec:** internal implementation — data structures, database models, language
and tool choices, algorithms.

Nail the user experience before arguing about implementation.

Sections, and what each is actually for:

| Section | Purpose |
|---|---|
| Disclaimer | States the spec is incomplete, so a draft doesn't get read as a commitment |
| Author | One name. Group-written specs are incoherent and unowned |
| Scenarios | Fictitious but stereotypical users doing typical tasks; vivid detail so design questions become answerable |
| Non-goals | What you're explicitly not doing this release ("we don't care about performance in v1") |
| Overview | Table of contents or flowchart — the big picture readers hang details on |
| Details | Every screen, every error case, every policy choice. "The most important thing" |
| Open issues | Unresolved questions, flagged during drafts, all closed before coding |
| Side notes | Audience-tagged asides for programmers, testers, marketing, docs |

And the anti-waterfall point: a spec is a living document, updated throughout
development until the code is done.

## Part 3 — who writes it

The **program manager** owns the design and the spec — roughly one PM per five
programmers at Microsoft. The job is bridging: customers, designers, developers, sales.

Qualities: clear writing, diplomacy, market awareness, UI/UX sense, deep technical
understanding (but not necessarily strong coding), and charisma.

Three structural mistakes:

1. **Don't promote a coder into the PM role.** Coding skill doesn't transfer.
1. **Don't staff PMs from marketing.** Not technical enough.
1. **Don't have developers report to the PM.** The PM leads by building consensus, not
   authority. Joel wrote a 500-page spec with zero supervisory power over anyone — having
   to persuade instead of command produced a better result.

## Part 4 — tips

1. **Be funny.** Specs get read only if they're enjoyable. Be specific — "Miss Piggy",
   not "the user".
1. **Writing a spec is like writing code for a brain to execute.** Give the big picture
   before the details; brains fault on abstractions and cache stories.
1. **Write as simply as possible.** "Use", not "utilize". Short sentences. Screenshots,
   bulleted lists, whitespace, and — as magazines do — a quote pulled into the middle of
   the page in a giant font, so the reader has somewhere to land.
1. **Review and reread** as many times as it takes. Any sentence that isn't instantly
   clear gets rewritten.
1. **Templates considered harmful.** Standard spec templates accumulate sections nobody
   needs, discourage people from writing at all, and stop each spec from finding its own
   shape.

## The sample spec — WhatTimeIsIt.com

A parody spec for a website that tells you the time, and the best available example of
the voice. Its shape:

**Disclaimers up front** — educational purpose, confidentiality, plus a joke one ("do
not stick WhatTimeIsIt.com in your ear").

**Overview** — the concept in one sentence, an explicit note that the spec is incomplete,
and a warning that graphics are illustrative only.

**Scenarios** — two named characters:

- *Mike*, a frantic executive juggling bank meetings and VCs, checking the time
  obsessively by 4:45 PM. The VCs demand a bonfire, because "Wall Street likes to see a
  bonfire."
- *Cindy*, a bright teenager who lands on the site by accident from a search engine.

The biographical detail is deliberately absurd — dynamite toys, half-siblings,
Teletubbies. It's funny, but it's also load-bearing: the details are what let you decide
whether Cindy would ever create an account.

**Non-goals** — three bullets, no hedging.

**Flowchart** — a sentence of setup, then the diagram of the user's path.

**Screen by screen** — Splash Screen, Home Page, Log In Form. Each gets a functional
description, a visual mockup with real sample text, interaction rules, and error handling
spelled out: the exact red error message, that the wrong entry is pre-populated and the
password field cleared, the extra line appended if CAPS LOCK looks like the culprit.
Field limits are pedantic on purpose — 60 characters for email, 12 for password, RFC-822
cited for address validation.

**Technical Notes** as sidebars — e.g. the $200,000 Vignette Story Server, with the
self-aware "sure, it's overkill" attached.

**Open Issues** flagged inline where they arise — awaiting marketing approval, bracketed
questions addressed straight at the developers.

The lesson to steal: the humour is in the *scenarios and the asides*; the details are
merciless and exact. Funny where it buys readership, precise where a programmer would
otherwise guess.
