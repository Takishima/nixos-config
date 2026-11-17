> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# Robotics design patterns skill index

Pick the pattern that matches the design problem and read its reference before sketching an architecture or reviewing one.

| Topic | When to read | Reference |
|---|---|---|
| Robot software stack | the layered architecture (drivers → perception → planning → control → behaviour) | `references/stack.md` |
| Behavior trees | composable, reactive behaviours; tick semantics; libraries (BehaviorTree.CPP, py_trees) | `references/behavior-trees.md` |
| Finite state machines | states, transitions, hierarchical FSMs; tools (smach, YASMIN, transitions) | `references/fsm.md` |
| Perception pipeline | producer → filter → fuse → publish; ROS 2 component composition | `references/perception-pipeline.md` |
| Hardware abstraction layer | abstracting motors, sensors, encoders; mock implementations for sim/test | `references/hal.md` |
| Safety systems | E-stop chain, safety controllers, watchdog isolation, redundancy, fail-safe defaults | `references/safety.md` |
| Sim-to-real architecture | sim/real swap via HAL, domain randomisation, parameter parity | `references/sim-to-real.md` |
| Data recording architecture | rosbag2, partial recording, on-event triggers, off-board sinks | `references/data-recording.md` |
| Anti-patterns to avoid | monolithic node, hidden coupling, sleep-based sequencing, hard-coded topics | `references/anti-patterns.md` |
| Architecture decision checklist | gate items before locking the architecture in | `references/checklist.md` |

## When to use this skill

- Designing robot software architecture from scratch
- Choosing between behaviour trees, FSMs, or hybrid approaches
- Structuring a perception-planning-control pipeline
- Designing the safety system / E-stop chain
- Building a sim-to-real-friendly architecture

After reading the matching reference, follow its guidance for the task.
