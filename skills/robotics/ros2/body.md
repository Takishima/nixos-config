> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# ROS 2 skill index

Pick the topic and read its reference before writing or reviewing ROS 2 code. The references cover the generic ROS 2 best-practice surface.

> **Supported versions (as of 2026-05):** Humble (LTS), Jazzy (LTS, recommended for greenfield),
> Kilted (latest non-LTS, EOL Dec 2026), Rolling. ROS 1 Noetic and ROS 2 Iron are EOL.
>
| Topic | When to read | Reference |
|---|---|---|
| Core architecture | executors, lifecycle, components, parameters, QoS, intra-process, actions, time, security overview | `references/architecture.md` |
| DDS configuration | CycloneDDS vs FastDDS, RMW selection, discovery, QoS profiles, network tuning | `references/dds.md` |
| Build system | colcon, ament_cmake, ament_python, custom message generation, workspace overlays, rosdep | `references/build.md` |
| Package structure (ROS 2) | layout of `CMakeLists.txt`, `package.xml`, `setup.py`, `launch/`, `config/`, `msg/`, `srv/`, `action/` | `references/packages.md` |
| Debugging toolkit | `ros2 topic`/`node`/`service`/`bag`, lifecycle introspection, DDS discovery, rosgraph | `references/debugging.md` |
| Production deployment | systemd, environment sourcing, micro-ROS, embedded targets, container vs host deployment | `references/deployment.md` |

## When to use this skill

- Building ROS 2 packages, nodes, or component containers
- Setting up colcon workspaces, ament_cmake, or ament_python packages
- Writing `CMakeLists.txt`, `package.xml`, or `setup.py` for ROS 2
- Defining custom messages, services, or actions
- Writing Python launch files with conditional logic
- Configuring DDS middleware and QoS profiles
- Implementing lifecycle (managed) nodes
- Working with Nav2, MoveIt2, or other ROS 2 frameworks
- Debugging DDS discovery, QoS mismatches, or build failures
- Deploying ROS 2 to production or embedded systems (micro-ROS)
- Setting up CI/CD for ROS 2 packages

After reading the matching reference, follow its guidance for the task.
