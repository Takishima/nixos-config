{
  name = "preflight";
  description = "Review a stack of commits that is finished but not yet up for review, spending a reviewer's attention budget as if it were scarce. Three passes: commit messages say why without over-explaining, carry their own justification, keep every prefix of the stack independently mergeable, and make no claim the author cannot check — plus no flip-flops, where one commit undoes another; a behaviour change to Nix or build-system code comes with the cheapest test that could actually fail; and every touched documentation paragraph earns its place in its Diataxis quadrant, with deletion as the default verdict. Reports findings with concrete rewrites and applies them on request — it never rewrites history unasked. Use when the user says \"preflight\", \"review my commits\", \"check my last few commits\", \"am I ready to push\", \"review before the MR\", or has just finished a stack of commits. For the squash-vs-keep-history decision use `assess-commits`; for commit and MR voice use `prose`; for writing docs use `docs`.";
  # Deliberately not `context = "fork"`: the docs pass rewrites the files it
  # reads, so a fork would read them twice. body.md caps the reads instead.
  allowedTools = "Read, Edit, Bash, Glob, Grep";
}
