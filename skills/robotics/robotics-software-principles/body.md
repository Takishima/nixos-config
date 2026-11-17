> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# Robotics software design principles skill index

Pick the principle that's load-bearing for the current decision and read its reference.

| Principle | When to read | Reference |
|---|---|---|
| Why robotics software is different | start here when explaining real-time / hardware constraints | `references/why-different.md` |
| Single responsibility | "one module, one job" applied to nodes / components | `references/single-responsibility.md` |
| Dependency inversion | depend on abstractions, not concrete hardware | `references/dependency-inversion.md` |
| Open-closed | extend behaviour without modifying stable code | `references/open-closed.md` |
| Interface segregation | small, focused interfaces over giant base classes | `references/interface-segregation.md` |
| Liskov substitution | replaceable implementations (real ↔ sim ↔ mock) | `references/liskov.md` |
| Separation of rates | respect timing boundaries between layers | `references/separation-of-rates.md` |
| Fail-safe defaults | safe until proven otherwise | `references/fail-safe.md` |
| Configuration over code | externalise everything that changes | `references/configuration.md` |
| Idempotent operations | safe to retry | `references/idempotent.md` |
| Observe everything | you can't debug what you can't see | `references/observability.md` |
| Composability | build complex behaviours from simple ones | `references/composability.md` |
| Graceful degradation | work with what you have | `references/degradation.md` |
| Principle checklist | quick-reference, scan after design | `references/checklist.md` |

## When to use this skill

- Designing robot software modules from scratch
- Structuring codebases or refactoring
- Code review for a robotics PR
- Designing APIs for a reusable robotics library
- Picking between two architectural approaches

After reading the matching reference, follow its guidance for the task.
