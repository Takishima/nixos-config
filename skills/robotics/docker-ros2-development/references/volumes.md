# Volume Mounts and Workspace Overlays

### Source Mounts for Dev

Mount only `src/` during development. Let colcon write `build/`, `install/`, and `log/` inside named volumes to avoid bind mount performance issues.

```yaml
# BAD: mounting entire workspace — build artifacts on bind mount are slow
# volumes:
#   - ./my_ros2_ws:/ros2_ws

# GOOD: mount only source, use named volumes for build artifacts
services:
  dev:
    image: my_robot:dev
    volumes:
      - ./src:/ros2_ws/src:rw                     # Source code (bind mount)
      - build_vol:/ros2_ws/build                   # Build artifacts (named volume)
      - install_vol:/ros2_ws/install               # Install space (named volume)
      - log_vol:/ros2_ws/log                       # Log output (named volume)
    working_dir: /ros2_ws

volumes:
  build_vol:
  install_vol:
  log_vol:
```

### ccache Caching

Persist ccache across container rebuilds for faster C++ compilation:

```yaml
services:
  dev:
    volumes:
      - ccache_vol:/ccache
    environment:
      - CCACHE_DIR=/ccache
      - CCACHE_MAXSIZE=2G
      - CC=ccache gcc
      - CXX=ccache g++
volumes:
  ccache_vol:
```

### ROS Workspace Overlay in Docker

Keep upstream packages cached and only rebuild custom packages:

```dockerfile
# Stage 1: upstream dependencies (rarely changes)
FROM ros:humble-ros-base AS upstream
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-nav2-bringup ros-humble-slam-toolbox \
    ros-humble-robot-localization \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: custom packages overlay on top
FROM upstream AS workspace
WORKDIR /ros2_ws
COPY src/ src/
RUN . /opt/ros/humble/setup.sh && colcon build --symlink-install
# install/setup.bash automatically sources /opt/ros/humble as underlay
```
