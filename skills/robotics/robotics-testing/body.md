> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# Robotics testing skill index

Pick the topic and read its reference before writing or reviewing a test.

| Topic | When to read | Reference |
|---|---|---|
| Robotics testing pyramid | the unit / integration / system / HIL hierarchy and where each lives | `references/pyramid.md` |
| Unit testing patterns | testing nodes in isolation, dependency injection, table-driven cases | `references/unit.md` |
| Integration testing | `launch_testing`, multi-node tests, async assertions | `references/integration.md` |
| Mock hardware patterns | mock drivers behind the HAL, recorded-data replay | `references/mocks.md` |
| Golden file testing | trajectory / map regression via golden files | `references/golden-files.md` |
| Simulation testing | Isaac Sim / Gazebo regression suites, determinism, randomisation | `references/simulation.md` |
| CI/CD pipeline for robotics | matrix builds, sim runners, GPU runners, HIL runners | `references/cicd.md` |
| Anti-patterns | flaky `sleep()`, hidden state, timing assumptions, leaking ROS domain | `references/anti-patterns.md` |

## When to use this skill

- Writing unit tests for ROS 1 / ROS 2 nodes
- Setting up integration tests with `launch_testing`
- Mocking hardware (sensors, actuators) for CI/CD
- Building golden-file regressions for trajectories / maps
- Setting up simulation tests
- Designing the CI/CD pipeline for a robotics repo

After reading the matching reference, follow its guidance for the task.
