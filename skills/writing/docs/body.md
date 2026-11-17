# docs

Three rules, in this order. Know what the document is for and who reads it.
Write it in plain language. Cut it to the shortest version that still does its
job.

## 1. Name the type and the reader first

Before writing, finish this sentence: *"This is a \<type> for \<reader>, who wants
to \<goal>."* If you cannot, use @{ask_user}. If the content needs two such
sentences, it is two documents.

| Type | The reader wants to | It contains | It does not contain (link instead) |
|---|---|---|---|
| **README** | decide if this is what they need, then start | what it is in one sentence, who it is for, install, one short example, links onward | option tables, every flag, architecture, design history, troubleshooting lists, changelog |
| **Tutorial** | learn by doing, the first time | one path that works, with the choices made for them | options, alternatives, explanation |
| **How-to guide** | reach a goal they already know | prerequisites, numbered steps, the one flag they need | background, rationale, full flag lists |
| **Reference** | look up a fact | every option, field or command, in the product's own structure: type, default, one example each | steps, opinions, rationale |
| **Explanation** (concepts, ADR, `ARCHITECTURE.md`) | understand why | context, trade-offs, rejected alternatives | steps, option lists, implementation detail |
| **Agent instructions** (`AGENTS.md`, `CLAUDE.md`) | let an AI agent work in the repo | what the code cannot tell it: conventions, commands, traps | anything the README or the code already says |
| **Option `description`, `--help`, docstring** | pick a value now | what it does, what the default means, when to change it | history, implementation |

A component README inside a larger repo says what the component does, how to
build and test it, and where it fits. Everything else lives in `docs/`.

Content that does not fit the type moves to the document that owns it, and this
one links there. If no such document exists and the reader needs one, write it.
Do not create empty pages for the sake of structure.

## 2. Plain language

The standard is ISO 24495-1:2023: readers can find what they need, understand
it, and act on it.

- **Common words.** *use*, not *utilize*; *start*, not *initiate*; *about*, not
  *approximately*.
- **One name per thing.** Define or link each term where it first appears.
  Spell out an acronym once.
- **Short sentences, one idea each.** Aim for 15 to 20 words on average.
- **Active voice, with the actor named.** *"The switch writes
  `/etc/nix/nix.conf`"*, not *"`/etc/nix/nix.conf` is written"*.
- **Talk to the reader.** Use *you*, and the imperative for instructions.
- **Verbs, not nouns made from verbs.** *decide*, not *make a decision*.
- **The point first.** The page opens with what the reader gets. Each section
  opens with its main sentence. A condition comes before its action: *"If the
  build fails, run …"*.
- **Concrete.** Real commands, paths and values. An example beats a paragraph.
- **The right shape.** Numbered lists for steps, tables to compare, sentences
  for reasons. No bullet list where one sentence does.
- **No filler.** Drop *simply*, *just*, *easily*, *note that*, *it is important
  to*, and hedges like *should generally*.

Docs stay neutral: no jokes, no first person, no opinions outside an
explanation's trade-offs. For the AI-tell catalogue, run steps 3a and 3c of the
`prose` skill.

## 3. Cut

Deletion is the default edit. Ask of each paragraph, and stop at the first
answer:

1. Would the reader miss it? If not, cut it.
1. Does the tool, its output or its error message already say it? Cut it.
1. Does the fact have a closer home: a name, an option `description`, `--help`,
   a docstring, a commit message? Put it there and cut it here.
1. Does another document already say it? Link to it.

No intro that previews the page, no summary that repeats it, no *"this document
describes"*. Fix a stale sentence instead of adding a correction under it. Do not
document around a defect; fix the behaviour. Between two versions that say the
same thing, ship the shorter one.

## Workflow

1. Write the type-and-reader sentence. Read the existing document and its
   neighbours (@{file_list_tools}) to see which one owns what.
1. Write or edit within that type's scope.
1. Do the plain-language pass, then the cut pass.
1. Check the result against `references/diataxis.md`, which lists the failures
   per type and the full paragraph-by-paragraph check.
1. When you hand back, state the type and reader, and list what you moved or cut
   and where it went.

When editing an existing document, finish one improvement rather than proposing
to restructure the doc tree. Diátaxis recommends small steps, each worth
shipping on its own.
