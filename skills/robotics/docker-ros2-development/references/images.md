# ROS2 Docker Image Hierarchy

Official OSRF images follow a layered hierarchy. Always choose the smallest base that satisfies dependencies.

```
┌──────────────────────────────────────────────────────────────────┐
│  ros:<distro>-desktop-full  (~3.5 GB)                            │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  ros:<distro>-desktop     (~2.8 GB)                        │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  ros:<distro>-perception (~2.2 GB)                    │  │  │
│  │  │  ┌────────────────────────────────────────────────┐   │  │  │
│  │  │  │  ros:<distro>-ros-base  (~1.1 GB)              │   │  │  │
│  │  │  │  ┌──────────────────────────────────────────┐  │   │  │  │
│  │  │  │  │  ros:<distro>-ros-core (~700 MB)         │  │   │  │  │
│  │  │  │  └──────────────────────────────────────────┘  │   │  │  │
│  │  │  └────────────────────────────────────────────────┘   │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

| Image Tag | Base OS | Size | Contents | Use Case |
|--------------------------|----------------|---------|---------------------------------------------|-------------------------------------|
| `ros:humble-ros-core` | Ubuntu 22.04 | ~700 MB | rclcpp, rclpy, rosout, launch | Minimal runtime for single nodes |
| `ros:humble-ros-base` | Ubuntu 22.04 | ~1.1 GB | ros-core + common_interfaces, rosbag2 | Most production deployments |
| `ros:humble-perception` | Ubuntu 22.04 | ~2.2 GB | ros-base + image_transport, cv_bridge, PCL | Camera/lidar perception pipelines |
| `ros:humble-desktop` | Ubuntu 22.04 | ~2.8 GB | perception + rviz2, rqt, demos | Development with GUI tools |
| `ros:jazzy-ros-core` | Ubuntu 24.04 | ~750 MB | rclcpp, rclpy, rosout, launch | Minimal runtime (Jazzy/Noble) |
| `ros:jazzy-ros-base` | Ubuntu 24.04 | ~1.2 GB | ros-core + common_interfaces, rosbag2 | Production deployments (Jazzy, recommended) |
| `ros:kilted-ros-core` | Ubuntu 24.04 | ~750 MB | rclcpp, rclpy, rosout, launch | Minimal runtime (Kilted, non-LTS, EOL Dec 2026) |
| `ros:kilted-ros-base` | Ubuntu 24.04 | ~1.2 GB | ros-core + common_interfaces, rosbag2 | Latest non-LTS deployments (Kilted) |
| `ros:iron-ros-base` | Ubuntu 22.04 | ~1.1 GB | ros-core + common_interfaces, rosbag2 | **EOL Dec 2024** — legacy only |
