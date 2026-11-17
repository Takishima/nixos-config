# Ordered Startup with Health Checks

### Startup Dependency Graph

Nodes must start in a specific order to avoid subscribing to topics that do not yet exist or calling services before they are available.

```
                    ┌──────────────┐
                    │  motors.srv  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ camera   │ │  lidar   │ │   imu    │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             ▼            ▼            ▼
        ┌──────────────────────────────────┐
        │        perception / SLAM         │
        └──────────────┬───────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │      navigation / planning       │
        └──────────────────────────────────┘
```

### Health Check Scripts

Use health check scripts in `ExecStartPre` to block service startup until dependencies are ready.

```bash
#!/bin/bash
# /usr/local/bin/robot-device-check.sh
# Verifies that all required hardware devices are present before starting drivers.
# Exit code 0 = all devices found, non-zero = missing device.

set -euo pipefail

REQUIRED_DEVICES=(
    "/dev/robot/camera_front"
    "/dev/robot/lidar"
    "/dev/robot/imu"
    "/dev/robot/motor_controller"
)

TIMEOUT=30
POLL_INTERVAL=1
elapsed=0

for device in "${REQUIRED_DEVICES[@]}"; do
    elapsed=0
    while [ ! -e "$device" ]; do
        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            echo "ERROR: Device $device not found after ${TIMEOUT}s" >&2
            exit 1
        fi
        echo "Waiting for $device... (${elapsed}s/${TIMEOUT}s)"
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    echo "Found device: $device"
done

echo "All required devices are present."
exit 0
```

```bash
#!/bin/bash
# /usr/local/bin/wait-for-ros2-nodes.sh
# Blocks until specified ROS2 nodes are active.
# Usage: wait-for-ros2-nodes.sh node_name1 node_name2 ...

set -euo pipefail

source /opt/ros/${ROS_DISTRO}/setup.bash
source /home/robot/ros2_ws/install/setup.bash

TIMEOUT=60
POLL_INTERVAL=2

for node_name in "$@"; do
    elapsed=0
    while ! ros2 node list 2>/dev/null | grep -q "$node_name"; do
        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            echo "ERROR: Node $node_name not found after ${TIMEOUT}s" >&2
            exit 1
        fi
        echo "Waiting for node $node_name... (${elapsed}s/${TIMEOUT}s)"
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    echo "Node active: $node_name"
done

echo "All required nodes are active."
exit 0
```

### Wait-for-Topic Pattern

A reusable Python utility to block until a topic is being published, useful for ordered startup in launch files.

```python
#!/usr/bin/env python3
# wait_for_topic.py
# Usage: python3 wait_for_topic.py /scan sensor_msgs/msg/LaserScan --timeout 30

import argparse
import sys
import time
import importlib

import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data


class TopicWaiter(Node):
    def __init__(self, topic_name, msg_type_str, timeout):
        super().__init__('topic_waiter')
        self.received = False
        self.timeout = timeout
        self.start_time = time.time()

        # Dynamically import the message type
        module_name, class_name = msg_type_str.rsplit('/', 1)
        module_name = module_name.replace('/', '.')
        module = importlib.import_module(module_name)
        msg_type = getattr(module, class_name)

        self.sub = self.create_subscription(
            msg_type, topic_name, self._callback, qos_profile_sensor_data)
        self.timer = self.create_timer(1.0, self._check_timeout)
        self.get_logger().info(f'Waiting for topic {topic_name}...')

    def _callback(self, msg):
        self.get_logger().info('Topic is active, message received.')
        self.received = True

    def _check_timeout(self):
        if self.received:
            raise SystemExit(0)
        elapsed = time.time() - self.start_time
        if elapsed > self.timeout:
            self.get_logger().error(f'Timeout after {self.timeout}s')
            raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('topic', help='Topic name to wait for')
    parser.add_argument('msg_type', help='Message type (e.g., sensor_msgs/msg/LaserScan)')
    parser.add_argument('--timeout', type=float, default=30.0)
    args = parser.parse_args()

    rclpy.init()
    node = TopicWaiter(args.topic, args.msg_type, args.timeout)
    rclpy.spin(node)


if __name__ == '__main__':
    main()
```

### Lifecycle Node Orchestration for Ordered Startup

Use lifecycle (managed) nodes to enforce startup ordering. A lifecycle manager configures and activates nodes in sequence, ensuring each node completes its configuration before the next one starts.

```python
# lifecycle_manager.launch.py
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    # Lifecycle manager controls the startup/shutdown order
    lifecycle_manager = Node(
        package='nav2_lifecycle_manager',
        executable='lifecycle_manager',
        name='lifecycle_manager',
        output='screen',
        parameters=[{
            # Nodes are transitioned in order: configure, then activate
            'node_names': [
                'motor_controller',
                'camera_driver',
                'lidar_driver',
                'slam',
                'navigation',
            ],
            'autostart': True,
            # Timeout for each node transition
            'bond_timeout': 10.0,
            # Check period for node bonds
            'bond_respawn_max_duration': 2.0,
        }],
    )

    return LaunchDescription([
        lifecycle_manager,
    ])
```
