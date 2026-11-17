{
  name = "summarize-history";
  description = "Summarize a branch's Git history into a merge-request title and a short, why-first description following the project template philosophy. Subroutine shared by create-mr and update-mr; also usable directly when the user asks to \"summarize my branch\", \"summarize the git history\", or \"draft an MR description from my commits\".";
  # Claude-only frontmatter fields (ignored by Codex/OpenCode per their docs).
  # Pin to the cheapest model — this is mechanical summarization of commit
  # subjects + a diffstat into a fixed contract. No deep reasoning needed.
  model = "haiku";
  effort = "low";
  # Pure task skill: git range in, small {TITLE, WHY, CHANGES} contract out.
  # Fork keeps the commit-log chatter out of the calling skill's context.
  context = "fork";
}
