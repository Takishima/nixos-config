# Graceful Shutdown Sequences

### Signal Handling in ROS2 Nodes

ROS2 nodes should handle `SIGINT` and `SIGTERM` to bring actuators to a safe state before exiting.

```python
#!/usr/bin/env python3
# safe_shutdown_node.py
# Demonstrates graceful shutdown with safe state transitions.

import signal
import sys

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
from std_msgs.msg import Bool


class SafeShutdownNode(Node):
    def __init__(self):
        super().__init__('safe_shutdown_node')

        self.cmd_vel_pub = self.create_publisher(Twist, '/cmd_vel', 10)
        self.brake_pub = self.create_publisher(Bool, '/brakes/engage', 10)

        # Register signal handlers for graceful shutdown
        signal.signal(signal.SIGTERM, self._shutdown_handler)
        signal.signal(signal.SIGINT, self._shutdown_handler)

        self.get_logger().info('Node started with graceful shutdown handler')

    def _shutdown_handler(self, signum, frame):
        """Handle shutdown signals by commanding safe state."""
        sig_name = signal.Signals(signum).name
        self.get_logger().warn(f'Received {sig_name}, initiating safe shutdown...')

        # Step 1: Command zero velocity immediately
        zero_twist = Twist()  # All fields default to 0.0
        for _ in range(5):
            self.cmd_vel_pub.publish(zero_twist)

        # Step 2: Engage brakes
        brake_msg = Bool()
        brake_msg.data = True
        self.brake_pub.publish(brake_msg)

        # Step 3: Wait briefly for commands to be received
        self.get_logger().info('Safe state commanded, shutting down...')

        # Step 4: Clean exit
        self.destroy_node()
        rclpy.shutdown()
        sys.exit(0)


def main():
    rclpy.init()
    node = SafeShutdownNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
```

### Ordered Shutdown via systemd Dependencies

The `PartOf` and `Before` directives ensure that application-level services are stopped before drivers, preventing the situation where a navigation node sends velocity commands after the motor driver has exited.

```ini
# /etc/systemd/system/robot-application.service
[Unit]
# ...
PartOf=robot-perception.service
Before=robot-perception.service

# When robot-perception stops, robot-application is stopped FIRST
# (Before= reverses the stop order relative to start order)

[Service]
# Use SIGINT for ROS2's signal handler, then SIGTERM, then SIGKILL
KillSignal=SIGINT
TimeoutStopSec=15
FinalKillSignal=SIGTERM
SendSIGKILL=yes
```

### Safe State on Shutdown

```python
# Use rclpy context shutdown callback for cleanup
import rclpy
from rclpy.node import Node


class ActuatorNode(Node):
    def __init__(self):
        super().__init__('actuator_node')
        self.cmd_pub = self.create_publisher(Twist, '/cmd_vel', 10)
        # Register a callback that runs during rclpy.shutdown()
        context = self.context
        context.on_shutdown(self._on_shutdown)

    def _on_shutdown(self):
        """Called automatically during rclpy.shutdown()."""
        self.get_logger().info('Shutdown callback: commanding zero velocity')
        self.cmd_pub.publish(Twist())
```
