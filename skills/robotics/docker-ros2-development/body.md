> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# Docker + ROS 2 skill index

Pick the topic and read its reference before writing or reviewing a ROS 2 container setup.

> **Supported versions (as of 2026-05):** Humble (LTS, Ubuntu 22.04), Jazzy (LTS, Ubuntu 24.04 — recommended), Kilted (non-LTS, Ubuntu 24.04, EOL Dec 2026), Rolling. Iron Irwini is EOL (Dec 2024); kept in image tables for legacy reference only.
>
| Topic | When to read | Reference |
|---|---|---|
| ROS 2 Docker image hierarchy | choosing between ros-core / ros-base / perception / desktop, tag conventions, image sizes | `references/images.md` |
| Multi-stage Dockerfiles | builder / runtime split, colcon cache, slim production images | `references/dockerfiles.md` |
| Docker Compose for multi-container ROS 2 | composing perception + planner + driver containers, healthchecks, ordering | `references/compose.md` |
| DDS discovery across containers | multicast across bridge / host / overlay networks, peer lists, daemon | `references/dds-discovery.md` |
| Networking modes | bridge vs host vs overlay vs ipvlan; ROS 2 implications | `references/networking.md` |
| GPU passthrough | NVIDIA driver, CDI / nvidia-docker, RealSense, ZED, OpenGL/CUDA in containers | `references/gpu.md` |
| Display forwarding | X11 / Wayland for rviz2 / rqt; xhost, DRI, mount sockets | `references/display.md` |
| Volume mounts and workspace overlays | dev-loop bind mounts, install/setup.bash propagation, .cache layouts | `references/volumes.md` |
| USB device pass-through | cameras, serial, FTDI, udev rules for `/dev/video*`, `/dev/ttyUSB*` | `references/usb.md` |
| Dev container configuration | VS Code devcontainer.json, ROS distro arg, post-create hooks | `references/devcontainer.md` |
| CI/CD with Docker | matrix builds across distros, layer caching, base-image rebuild triggers | `references/cicd.md` |
| Anti-patterns | what to avoid (root containers, fat images, baking secrets, leaking host net) | `references/anti-patterns.md` |
| Production checklist | gate items before shipping a ROS 2 container | `references/checklist.md` |

## When to use this skill

- Containerizing a ROS 2 workspace
- Setting up docker-compose for a multi-container robot stack
- Debugging DDS discovery between containers
- Configuring NVIDIA Container Toolkit / CDI for GPU workloads
- Forwarding X11 / Wayland for rviz2 and GUI tools
- Pass-through of USB cameras or serial devices
- CI/CD for Docker-based ROS 2 builds

After reading the matching reference, follow its guidance for the task.
