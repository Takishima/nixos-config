# Watchdog and Heartbeat Monitoring

### systemd Watchdog Integration

When `WatchdogSec` is set in the service unit, the process must periodically notify systemd that it is alive. If the notification is missed, systemd restarts the service.

```python
#!/usr/bin/env python3
# watchdog_node.py
# A ROS2 node that integrates with systemd watchdog via sd_notify.

import os
import socket
import time

import rclpy
from rclpy.node import Node
from diagnostic_msgs.msg import DiagnosticArray, DiagnosticStatus


class WatchdogNode(Node):
    """Notifies systemd that the ROS2 process is alive."""

    def __init__(self):
        super().__init__('watchdog_node')

        # Read the watchdog interval from systemd environment
        watchdog_usec = os.environ.get('WATCHDOG_USEC')
        if watchdog_usec:
            # Notify at half the watchdog interval for safety margin
            interval_sec = int(watchdog_usec) / 1_000_000 / 2.0
        else:
            interval_sec = 10.0
            self.get_logger().warn('WATCHDOG_USEC not set, using 10s interval')

        # Connect to systemd notification socket
        self.notify_socket = os.environ.get('NOTIFY_SOCKET')

        # Signal that startup is complete
        self._sd_notify('READY=1')
        self.get_logger().info(
            f'Watchdog node started, notify interval: {interval_sec:.1f}s')

        # Periodically send watchdog keepalive
        self.create_timer(interval_sec, self._watchdog_tick)

        # Subscribe to system diagnostics to detect failures
        self.diag_sub = self.create_subscription(
            DiagnosticArray, '/diagnostics', self._diag_callback, 10)
        self.system_healthy = True

    def _watchdog_tick(self):
        """Send watchdog keepalive to systemd if system is healthy."""
        if self.system_healthy:
            self._sd_notify('WATCHDOG=1')
        else:
            self.get_logger().error(
                'System unhealthy, withholding watchdog notification')

    def _diag_callback(self, msg):
        """Monitor diagnostics for critical errors."""
        for status in msg.status:
            if status.level == DiagnosticStatus.ERROR:
                self.get_logger().error(f'Critical error: {status.name}: {status.message}')
                self.system_healthy = False
                return
        self.system_healthy = True

    def _sd_notify(self, state):
        """Send notification to systemd."""
        if not self.notify_socket:
            return
        addr = self.notify_socket
        if addr[0] == '@':
            addr = '\0' + addr[1:]
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        try:
            sock.connect(addr)
            sock.sendall(state.encode())
        finally:
            sock.close()


def main():
    rclpy.init()
    node = WatchdogNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
```

### ROS2-Level Heartbeat Monitor Node

A monitor node that subscribes to heartbeat topics from critical subsystems and publishes overall system health. If a heartbeat is missed, it triggers a safe stop.

```python
#!/usr/bin/env python3
# heartbeat_monitor.py
# Monitors heartbeats from critical nodes and triggers safe stop if any go silent.

import time

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, DurabilityPolicy
from std_msgs.msg import Bool, String
from geometry_msgs.msg import Twist
from diagnostic_msgs.msg import DiagnosticArray, DiagnosticStatus, KeyValue


class HeartbeatMonitor(Node):
    def __init__(self):
        super().__init__('heartbeat_monitor')

        # Declare parameters for monitored nodes and timeout
        self.declare_parameter('monitored_nodes', [
            'motor_controller', 'camera_driver', 'lidar_driver', 'slam'
        ])
        self.declare_parameter('heartbeat_timeout_sec', 5.0)
        self.declare_parameter('check_period_sec', 1.0)

        self.monitored_nodes = self.get_parameter('monitored_nodes').value
        self.timeout = self.get_parameter('heartbeat_timeout_sec').value
        check_period = self.get_parameter('check_period_sec').value

        # Track last heartbeat time for each monitored node
        self.last_heartbeat = {name: time.time() for name in self.monitored_nodes}

        # Subscribe to each node's heartbeat topic
        reliable_qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
            depth=1,
        )
        for node_name in self.monitored_nodes:
            self.create_subscription(
                Bool, f'/{node_name}/heartbeat',
                lambda msg, n=node_name: self._heartbeat_callback(n, msg),
                reliable_qos,
            )

        # Publishers
        self.health_pub = self.create_publisher(
            DiagnosticArray, '/system_health', 10)
        self.estop_pub = self.create_publisher(
            Bool, '/emergency_stop', reliable_qos)
        self.cmd_vel_pub = self.create_publisher(
            Twist, '/cmd_vel', 10)

        # Periodic health check
        self.create_timer(check_period, self._check_health)
        self.get_logger().info(
            f'Monitoring heartbeats for: {self.monitored_nodes}')

    def _heartbeat_callback(self, node_name, msg):
        """Record heartbeat reception time."""
        self.last_heartbeat[node_name] = time.time()

    def _check_health(self):
        """Check all heartbeats and publish diagnostics."""
        now = time.time()
        diag_array = DiagnosticArray()
        diag_array.header.stamp = self.get_clock().now().to_msg()
        all_healthy = True

        for node_name in self.monitored_nodes:
            elapsed = now - self.last_heartbeat[node_name]
            status = DiagnosticStatus()
            status.name = f'heartbeat/{node_name}'

            if elapsed < self.timeout:
                status.level = DiagnosticStatus.OK
                status.message = f'Alive ({elapsed:.1f}s ago)'
            else:
                status.level = DiagnosticStatus.ERROR
                status.message = f'TIMEOUT ({elapsed:.1f}s since last heartbeat)'
                all_healthy = False
                self.get_logger().error(
                    f'Heartbeat timeout for {node_name}: {elapsed:.1f}s')

            status.values = [
                KeyValue(key='elapsed_sec', value=f'{elapsed:.2f}'),
                KeyValue(key='timeout_sec', value=f'{self.timeout:.2f}'),
            ]
            diag_array.status.append(status)

        self.health_pub.publish(diag_array)

        if not all_healthy:
            self._trigger_safe_stop()

    def _trigger_safe_stop(self):
        """Send zero velocity and emergency stop signal."""
        self.get_logger().warn('Triggering safe stop due to heartbeat failure')
        # Publish zero velocity
        self.cmd_vel_pub.publish(Twist())
        # Publish emergency stop
        estop_msg = Bool()
        estop_msg.data = True
        self.estop_pub.publish(estop_msg)


def main():
    rclpy.init()
    node = HeartbeatMonitor()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
```

### Hardware Watchdog Integration

Many robot onboard computers have a hardware watchdog timer (e.g., Intel TCO, iTCO_wdt). If the software fails to pet the watchdog, the hardware performs a hard reboot.

```bash
# Enable the hardware watchdog in systemd
# /etc/systemd/system.conf
# RuntimeWatchdogSec=30
# RebootWatchdogSec=10min
# ShutdownWatchdogSec=10min

# Or configure per-service in the unit file:
# WatchdogSec=30 triggers systemd to restart the service
# The hardware watchdog (configured via RuntimeWatchdogSec) reboots
# the entire machine if systemd itself becomes unresponsive.

# Verify hardware watchdog is active
sudo cat /sys/class/watchdog/watchdog0/state
# Should output: active

# Check watchdog timeout
sudo cat /sys/class/watchdog/watchdog0/timeout
```
