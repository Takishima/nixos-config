{
  name = "find-mr";
  description = "This skill should be used whenever the user references \"the MR\", \"this MR\", \"my MR\", \"latest review comments\", \"reviewer feedback\", \"MR CI\", \"MR pipeline\", or any MR-related task on the current branch WITHOUT an explicit MR number. Detects the open GitLab MR whose source branch is the currently checked-out branch and returns its number and URL for downstream use.";
  # Claude-only frontmatter fields (ignored by Codex/OpenCode per their docs).
  # Pin to the cheapest model — this skill is mechanical: one glab call + regex parse.
  model = "haiku";
  effort = "low";
  # Pure task skill: noisy glab lookup in, small {MR#, URL} out, no need for
  # conversation history. Fork keeps the lookup chatter out of the main context.
  context = "fork";
}
