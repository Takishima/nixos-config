# Docker Compose for Multi-Container ROS2 Systems

### Basic Multi-Container Setup

Each ROS2 subsystem runs in its own container with process isolation, independent scaling, and per-service resource limits.

```yaml
# docker-compose.yml
version: "3.8"

x-ros-common: &ros-common
  environment:
    - ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}
    - RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    - CYCLONEDDS_URI=file:///cyclonedds.xml
  volumes:
    - ./config/cyclonedds.xml:/cyclonedds.xml:ro
    - /dev/shm:/dev/shm
  network_mode: host
  restart: unless-stopped

services:
  rosbridge:
    <<: *ros-common
    image: my_robot:latest
    command: ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9090

  perception:
    <<: *ros-common
    image: my_robot_perception:latest
    command: ros2 launch my_robot_perception perception.launch.py
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    devices:
      - /dev/video0:/dev/video0            # USB camera passthrough

  navigation:
    <<: *ros-common
    image: my_robot_navigation:latest
    command: >
      ros2 launch my_robot_navigation navigation.launch.py
        use_sim_time:=false map:=/maps/warehouse.yaml
    volumes:
      - ./maps:/maps:ro

  driver:
    <<: *ros-common
    image: my_robot_driver:latest
    command: ros2 launch my_robot_driver driver.launch.py
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0          # Serial motor controller
      - /dev/ttyACM0:/dev/ttyACM0          # IMU over USB-serial
    group_add:
      - dialout
```

### Service Dependencies with Health Checks

```yaml
services:
  driver:
    <<: *ros-common
    image: my_robot_driver:latest
    healthcheck:
      test: ["CMD", "bash", "-c",
             "source /opt/ros/humble/setup.bash && ros2 topic list | grep -q /joint_states"]
      interval: 5s
      timeout: 10s
      retries: 5
      start_period: 15s

  navigation:
    <<: *ros-common
    image: my_robot_navigation:latest
    depends_on:
      driver:
        condition: service_healthy         # Wait for driver topics

  perception:
    <<: *ros-common
    image: my_robot_perception:latest
    depends_on:
      driver:
        condition: service_healthy         # Camera driver must be ready
```

### Profiles for Dev vs Deploy

```yaml
services:
  driver:
    <<: *ros-common
    image: my_robot_driver:latest
    command: ros2 launch my_robot_driver driver.launch.py

  rviz:
    <<: *ros-common
    profiles: ["dev"]
    image: my_robot:dev
    command: ros2 run rviz2 rviz2 -d /rviz/config.rviz
    environment:
      - DISPLAY=${DISPLAY}
      - QT_X11_NO_MITSHM=1
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw

  rosbag_record:
    <<: *ros-common
    profiles: ["dev"]
    image: my_robot:dev
    command: ros2 bag record -a --storage sqlite3 --max-bag-duration 300 -o /bags/session
    volumes:
      - ./bags:/bags

  watchdog:
    <<: *ros-common
    profiles: ["deploy"]
    image: my_robot:latest
    command: ros2 launch my_robot_bringup watchdog.launch.py
    restart: always
```

```bash
docker compose --profile dev up          # Dev tools (rviz, rosbag)
docker compose --profile deploy up -d    # Production (watchdog, no GUI)
```
