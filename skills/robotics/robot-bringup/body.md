> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# Robot bringup skill index

Pick the topic and read its reference before configuring or debugging a robot bringup stack.

> **Supported versions (as of 2026-05):** Ubuntu 22.04/24.04 with ROS 2 Humble (LTS) or Jazzy (LTS, recommended). Iron Irwini is EOL (Dec 2024).
>
| Topic | When to read | Reference |
|---|---|---|
| Robot bringup stack | the layered architecture (drivers → state → behaviour → ui) | `references/architecture.md` |
| systemd service units for ROS 2 | `.service` files, `Type=`, `Restart=`, environment, dependencies | `references/systemd.md` |
| Launch file composition and layering | top-level launcher, sub-launches, namespaces, args, includes | `references/launch.md` |
| Ordered startup with health checks | health gates, `wait-for-it` patterns, lifecycle handshakes | `references/startup.md` |
| udev rules for deterministic device naming | `/dev/realsense_color`, `/dev/lidar_front`, `MODE=`, `SYMLINK=` | `references/udev.md` |
| Network configuration for multi-machine ROS 2 | `ROS_DOMAIN_ID`, RMW selection, multicast, ethernet bonding | `references/network.md` |
| Watchdog and heartbeat monitoring | software watchdogs, hardware watchdog (`/dev/watchdog`), node liveness | `references/watchdog.md` |
| Logging and rotation | `rclcpp` logging, journald, logrotate, disk-pressure | `references/logging.md` |
| Graceful shutdown sequences | `systemctl stop`, signal handling, lifecycle `deactivate` chain | `references/shutdown.md` |
| Remote monitoring and debugging | SSH, journalctl, tmux on the robot, port forwards for rviz2 | `references/monitoring.md` |
| Anti-patterns | what to avoid (root services, baked secrets, no respawn cap) | `references/anti-patterns.md` |
| Production checklist | gate items before shipping a robot | `references/checklist.md` |

## When to use this skill

- Configuring a robot to start ROS 2 nodes on boot
- Writing systemd units for ROS 2 launch
- Composing layered launch files for a full robot stack
- Setting up watchdog monitoring or hardware watchdog
- Writing udev rules for deterministic device naming
- Debugging boot-time race conditions
- Configuring multi-machine ROS 2 networks

After reading the matching reference, follow its guidance for the task.
