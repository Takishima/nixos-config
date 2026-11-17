# Multi-Stage Dockerfiles for ROS2

### Dev Stage

The development stage includes build tools, debuggers, and editor support for interactive use.

```dockerfile
FROM ros:humble-desktop AS dev
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake gdb python3-pip \
    python3-colcon-common-extensions python3-rosdep \
    ros-humble-ament-lint-auto ros-humble-ament-cmake-pytest \
    ccache \
    && rm -rf /var/lib/apt/lists/*
ENV CCACHE_DIR=/ccache
ENV CC="ccache gcc"
ENV CXX="ccache g++"
```

### Build Stage

Copies only `src/` and `package.xml` files to maximize cache hits during dependency resolution.

```dockerfile
FROM ros:humble-ros-base AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions python3-rosdep \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /ros2_ws
# Copy package manifests first for dependency caching
COPY src/my_pkg/package.xml src/my_pkg/package.xml
RUN . /opt/ros/humble/setup.sh && apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    rm -rf /var/lib/apt/lists/*
# Source changes invalidate only this layer and below
COPY src/ src/
RUN . /opt/ros/humble/setup.sh && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release \
      --event-handlers console_direct+
```

### Runtime Stage

Contains only the built install space and runtime dependencies. No compilers, no source code.

```dockerfile
FROM ros:humble-ros-core AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-yaml ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /ros2_ws/install /ros2_ws/install
RUN groupadd -r rosuser && useradd -r -g rosuser -m rosuser
USER rosuser
COPY ros_entrypoint.sh /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["ros2", "launch", "my_pkg", "bringup.launch.py"]
```

### Full Multi-Stage Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
# Usage:
#   docker build --target dev -t my_robot:dev .
#   docker build --target runtime -t my_robot:latest .
ARG ROS_DISTRO=humble
ARG BASE_IMAGE=ros:${ROS_DISTRO}-ros-base

# Stage 1: Dependency base — install apt and rosdep deps
FROM ${BASE_IMAGE} AS deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions python3-rosdep \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /ros2_ws
# Copy only package.xml files for rosdep resolution (maximizes cache reuse)
COPY src/my_robot_bringup/package.xml src/my_robot_bringup/package.xml
COPY src/my_robot_perception/package.xml src/my_robot_perception/package.xml
COPY src/my_robot_msgs/package.xml src/my_robot_msgs/package.xml
COPY src/my_robot_navigation/package.xml src/my_robot_navigation/package.xml
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    rm -rf /var/lib/apt/lists/*

# Stage 2: Development — full dev environment
FROM deps AS dev
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gdb valgrind ccache python3-pip python3-pytest \
    ros-${ROS_DISTRO}-ament-lint-auto \
    ros-${ROS_DISTRO}-launch-testing-ament-cmake \
    ros-${ROS_DISTRO}-rviz2 ros-${ROS_DISTRO}-rqt-graph \
    && rm -rf /var/lib/apt/lists/*
ENV CCACHE_DIR=/ccache CC="ccache gcc" CXX="ccache g++"
COPY src/ src/
COPY ros_entrypoint.sh /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

# Stage 3: Build — compile workspace
FROM deps AS build
COPY src/ src/
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    colcon build \
      --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
      --event-handlers console_direct+ \
      --parallel-workers $(nproc)

# Stage 4: Runtime — minimal production image
FROM ros:${ROS_DISTRO}-ros-core AS runtime
ARG ROS_DISTRO=humble
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-yaml ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /ros2_ws/install /ros2_ws/install
RUN groupadd -r rosuser && useradd -r -g rosuser -m -s /bin/bash rosuser
USER rosuser
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
COPY ros_entrypoint.sh /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["ros2", "launch", "my_robot_bringup", "robot.launch.py"]
```

The entrypoint script both dev and runtime stages use:

```bash
#!/bin/bash
set -e
source /opt/ros/${ROS_DISTRO}/setup.bash
if [ -f /ros2_ws/install/setup.bash ]; then
    source /ros2_ws/install/setup.bash
fi
exec "$@"
```
