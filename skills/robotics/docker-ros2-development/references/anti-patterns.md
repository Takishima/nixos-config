# Docker ROS2 Anti-Patterns

### 1. Running Everything in One Container

**Problem:** Putting perception, navigation, planning, and drivers in a single container defeats the purpose of containerization. A crash in one subsystem takes down everything.

**Fix:** Split into one service per subsystem. Use docker-compose to orchestrate.

```yaml
# BAD: monolithic container
services:
  robot:
    image: my_robot:latest
    command: ros2 launch my_robot everything.launch.py

# GOOD: one container per subsystem
services:
  perception:
    image: my_robot_perception:latest
    command: ros2 launch my_robot_perception perception.launch.py
  navigation:
    image: my_robot_navigation:latest
    command: ros2 launch my_robot_navigation navigation.launch.py
  driver:
    image: my_robot_driver:latest
    command: ros2 launch my_robot_driver driver.launch.py
```

### 2. Using Bridge Networking Without DDS Config

**Problem:** DDS uses multicast for discovery by default. Docker bridge networks do not forward multicast. Nodes in different containers will not discover each other.

**Fix:** Use `network_mode: host` or configure DDS unicast peers explicitly.

```yaml
# BAD: bridge network with no DDS config
services:
  node_a:
    networks: [ros_net]
  node_b:
    networks: [ros_net]

# GOOD: host networking (simplest)
services:
  node_a:
    network_mode: host
  node_b:
    network_mode: host

# GOOD: bridge with CycloneDDS unicast peers
services:
  node_a:
    networks: [ros_net]
    environment:
      - RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
      - CYCLONEDDS_URI=file:///cyclonedds.xml
    volumes:
      - ./cyclonedds.xml:/cyclonedds.xml:ro
```

### 3. Building Packages in the Runtime Image

**Problem:** Installing compilers and build tools in the runtime image bloats it by 1-2 GB and increases attack surface.

**Fix:** Use multi-stage builds. Compile in a build stage, copy only the install space to runtime.

```dockerfile
# BAD: build tools in runtime image (2.5 GB)
FROM ros:humble-ros-base
RUN apt-get update && apt-get install -y build-essential python3-colcon-common-extensions
COPY src/ /ros2_ws/src/
RUN cd /ros2_ws && colcon build
CMD ["ros2", "launch", "my_pkg", "bringup.launch.py"]

# GOOD: multi-stage build (800 MB)
FROM ros:humble-ros-base AS build
RUN apt-get update && apt-get install -y python3-colcon-common-extensions
COPY src/ /ros2_ws/src/
RUN cd /ros2_ws && . /opt/ros/humble/setup.sh && colcon build

FROM ros:humble-ros-core AS runtime
COPY --from=build /ros2_ws/install /ros2_ws/install
CMD ["ros2", "launch", "my_pkg", "bringup.launch.py"]
```

### 4. Mounting the Entire Workspace as a Volume

**Problem:** Mounting the full workspace means colcon writes `build/`, `install/`, and `log/` to a bind mount. Build artifacts on a bind mount also collide with host file ownership and slow rebuilds. Use a named volume for the artifact dirs instead.

**Fix:** Mount only `src/` as a bind mount. Use named volumes for build artifacts.

```yaml
# BAD:
volumes:
  - ./my_ros2_ws:/ros2_ws

# GOOD:
volumes:
  - ./my_ros2_ws/src:/ros2_ws/src
  - build_vol:/ros2_ws/build
  - install_vol:/ros2_ws/install
  - log_vol:/ros2_ws/log
```

### 5. Running Containers as Root

**Problem:** Running as root inside containers is a security risk. If compromised, the attacker has root access to mounted volumes and devices.

**Fix:** Create a non-root user with appropriate group membership.

```dockerfile
# BAD:
FROM ros:humble-ros-base
COPY --from=build /ros2_ws/install /ros2_ws/install
CMD ["ros2", "launch", "my_pkg", "bringup.launch.py"]

# GOOD:
FROM ros:humble-ros-base
RUN groupadd -r rosuser && \
    useradd -r -g rosuser -G video,dialout -m -s /bin/bash rosuser
COPY --from=build --chown=rosuser:rosuser /ros2_ws/install /ros2_ws/install
USER rosuser
CMD ["ros2", "launch", "my_pkg", "bringup.launch.py"]
```

### 6. Ignoring Layer Cache Order in Dockerfile

**Problem:** Placing `COPY src/ .` before `rosdep install` means every source change invalidates the dependency cache. All apt packages are re-downloaded on every build.

**Fix:** Copy only `package.xml` files first, install dependencies, then copy source.

```dockerfile
# BAD: source copy before rosdep
COPY src/ /ros2_ws/src/
RUN rosdep install --from-paths src --ignore-src -r -y
RUN colcon build

# GOOD: package.xml first, then rosdep, then source
COPY src/my_pkg/package.xml /ros2_ws/src/my_pkg/package.xml
RUN . /opt/ros/humble/setup.sh && rosdep install --from-paths src --ignore-src -r -y
COPY src/ /ros2_ws/src/
RUN . /opt/ros/humble/setup.sh && colcon build
```

### 7. Hardcoding ROS_DOMAIN_ID

**Problem:** Hardcoding `ROS_DOMAIN_ID=42` causes conflicts when multiple robots or developers share a network. Two robots with the same domain ID will cross-talk.

**Fix:** Use environment variables with defaults. Set domain ID at deploy time.

```yaml
# BAD:
environment:
  - ROS_DOMAIN_ID=42

# GOOD:
environment:
  - ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}
```

```bash
ROS_DOMAIN_ID=1 docker compose up -d    # Robot 1
ROS_DOMAIN_ID=2 docker compose up -d    # Robot 2
```

### 8. Forgetting to Source setup.bash in Entrypoint

**Problem:** The `CMD` runs `ros2 launch ...` but the shell has not sourced the ROS2 setup files. Fails with `ros2: command not found`.

**Fix:** Use an entrypoint script that sources the underlay and overlay before executing the command.

```dockerfile
# BAD: no sourcing
FROM ros:humble-ros-core
COPY --from=build /ros2_ws/install /ros2_ws/install
CMD ["ros2", "launch", "my_pkg", "bringup.launch.py"]

# GOOD: entrypoint script handles sourcing
FROM ros:humble-ros-core
COPY --from=build /ros2_ws/install /ros2_ws/install
COPY ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["ros2", "launch", "my_pkg", "bringup.launch.py"]
```

```bash
#!/bin/bash
# ros_entrypoint.sh
set -e
source /opt/ros/${ROS_DISTRO}/setup.bash
if [ -f /ros2_ws/install/setup.bash ]; then
    source /ros2_ws/install/setup.bash
fi
exec "$@"
```
