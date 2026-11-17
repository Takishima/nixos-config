# Authoring GitLab CI/CD pipelines

Scope: writing and editing `.gitlab-ci.yml` — pipeline structure, reuse,
downstream pipelines, caching, deployment safety, and the YAML gotchas that
cause real production breakage. This skill does **not** cover the `glab` CLI,
merge-request creation, or job-failure triage — use `create-mr`/`find-mr` and
`diagnose-ci-job` for those.

Read the reference before editing pipeline config:

| Topic | Reference |
|---|---|
| YAML gotchas (rules, merge traps, artifacts vs cache, dind, duplicate pipelines), components & `spec:inputs`, downstream/parent-child/multi-project pipelines, caching, resource groups, OIDC secrets, decision trees | `references/cicd.md` |
| Complete copy-from pipeline templates (Node.js, Docker) | `references/cicd/pipeline-templates.md` |

After reading the reference, follow its guidance for the task.
