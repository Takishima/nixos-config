# Container Security

### Non-Root Containers

```dockerfile
FROM ros:humble-ros-base AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-nav2-bringup && rm -rf /var/lib/apt/lists/*
RUN groupadd -g 1000 robot && useradd -u 1000 -g robot -m -s /bin/false robot
COPY --from=builder /opt/ros2_ws/install /opt/ros2_ws/install
USER robot:robot
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["ros2", "launch", "my_robot", "nav.launch.py"]
```

### Minimal Runtime Images

```dockerfile
FROM ros:humble-desktop AS builder
WORKDIR /opt/ros2_ws
COPY src/ src/
RUN . /opt/ros/humble/setup.sh && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release --merge-install

FROM ros:humble-ros-core AS runtime
COPY --from=builder /opt/ros2_ws/install /opt/ros2_ws/install
# Remove shell and package manager — prevents interactive exploitation
RUN rm -f /bin/sh /bin/bash /bin/dash && apt-get purge -y --auto-remove apt
```

### Image Scanning and Signing

```bash
trivy image --severity HIGH,CRITICAL my-robot/navigation:latest
cosign sign --key cosign.key my-registry.io/my-robot/navigation:v1.2.3
cosign verify --key cosign.pub my-registry.io/my-robot/navigation:v1.2.3 || exit 1
```

### Read-Only Root Filesystem

```yaml
# docker-compose.yml
services:
  motor_controller:
    image: my-robot/motor-controller:v1.0.0
    user: "1000:1000"
    read_only: true
    tmpfs: ["/tmp:size=64M", "/var/log/ros:size=32M"]
    volumes:
      - type: bind
        source: /opt/robot/sros2_keystore/enclaves/my_robot/motor_controller
        target: /keystore
        read_only: true
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]
    environment:
      ROS_SECURITY_KEYSTORE: /keystore
      ROS_SECURITY_ENABLE: "true"
      ROS_SECURITY_STRATEGY: Enforce
```
