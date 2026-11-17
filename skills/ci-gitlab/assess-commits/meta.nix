{
  name = "assess-commits";
  description = "Assess whether a branch's commits are self-contained, review-worthy steps or just scaffolding, and recommend squash vs keep-history for the merge. Subroutine invoked by create-mr to steer the squash decision; also usable directly when the user asks \"should I squash?\", \"are my commits clean?\", or \"is this history worth keeping?\".";
  # Claude-only frontmatter (ignored by Codex/OpenCode per their docs).
  # Cheap model: reads commit messages + per-commit diffstats and applies a
  # cohesion heuristic into a fixed contract. Judgment, but shallow.
  model = "haiku";
  effort = "low";
  # Pure task skill: git range in, small {RECOMMENDATION, RATIONALE} out.
  # Fork keeps the per-commit diff chatter out of the caller's context.
  context = "fork";
}
