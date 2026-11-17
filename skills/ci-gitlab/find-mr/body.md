# Find GitLab MR for Current Branch

Detect the open GitLab MR whose source branch is the currently checked-out branch, and return its number and URL for downstream use.

This skill is intentionally light: one shell call plus a regex parse. No deep reasoning needed — keep the response short.

## When to Use

Activate whenever the user references:

- "the MR", "this MR", "my MR" (without an explicit `!<number>`)
- "latest review comments", "reviewer feedback", "address review"
- "MR CI", "MR pipeline", "is my MR green"
- Any MR-related task on the current branch that doesn't name the MR

Do NOT run if the user already gave an explicit MR number (e.g. `!11404`) — use that directly.

## Workflow

### Step 1: Detect the current branch

```bash
BRANCH=$(git branch --show-current)
if [ -z "$BRANCH" ]; then
  echo "NO_BRANCH: detached HEAD or not on a branch"
  exit 0
fi
```

If no branch, report to the user and stop.

### Step 2: List open MRs for the branch

```bash
# glab reads the GitLab repo from the git remote automatically.
MRS=$(glab mr list --source-branch="$BRANCH" 2>/dev/null)
```

If the working tree has multiple GitLab remotes and the user has a preferred one, pass `--repo <group/project>` explicitly.

### Step 3: Parse and emit

Extract MR numbers from the output (they appear as `!<digits>` in glab's list format).

- **0 matches** → emit exactly:

  ```
  NO_MR
  ```

  Then tell the user no open MR exists for `$BRANCH` and offer `/create-mr` as the next step.

- **1 match** → fetch the URL and emit exactly:

  ```
  FOUND_MR: !<number> <url>
  ```

  URL comes from `glab mr view <number> --output json` (parse `web_url` field) or directly from the `list` row if glab prints it. Pass the emitted line back so the main agent can consume it.

- **>1 match** → print the short list and use @{ask_user} to pick one. After the user picks, emit `FOUND_MR: !<number> <url>` for that MR.

### Step 4: Optional — closed/merged fallback

Only if Step 2 returned zero open MRs AND the user's phrasing suggests a non-open MR (e.g. "the MR I merged yesterday"):

```bash
glab mr list --source-branch="$BRANCH" --state=merged
glab mr list --source-branch="$BRANCH" --state=closed
```

Otherwise skip — the default is open MRs only.

## Output Contract

Emit exactly one of these lines so the main agent can grep for it:

```
FOUND_MR: !<number> <url>
```

```
NO_MR
```

Keep output minimal — downstream prompts should trivially extract the MR number.

## Notes

This skill does not fetch review comments or CI status; it's a detection subroutine. Action skills run afterward, using the emitted MR number.
