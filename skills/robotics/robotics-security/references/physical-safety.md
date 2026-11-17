# Physical-Cyber Safety Intersection

Cyber attacks on robots cause **physical harm**. Standard IT security is necessary but not sufficient.

### E-Stop Independence

The emergency stop **must** function with all software, network, and main compute completely dead.

```
  ┌──────────┐     HARDWIRED      ┌─────────────────┐
  │ Physical  │ ─────────────────▶│ Safety Relay /   │──▶ Motor power cut
  │ E-Stop    │  Direct circuit    │ Safety PLC       │   via contactor
  │ Button    │  NO software       └─────────────────┘
  └──────────┘
  ┌──────────┐     OPTIONAL
  │ Software  │ ───(notifies)───▶ Can trigger relay, but NOT sole path
  │ E-Stop    │
  └──────────┘
  Main compute crash ──X──▶ Cannot prevent hardware e-stop
  Network failure    ──X──▶ Cannot prevent hardware e-stop
```

Design rules: hardwired circuit disconnects motor power; software triggers the relay but is never the only path; wireless e-stops use dedicated radio, not WiFi.

### Safety Controller Isolation

```
┌──────────────────────────────┬───────────────────────────────┐
│ MAIN COMPUTE (Jetson/x86)    │ SAFETY CONTROLLER (STM32/MCU) │
│ Ubuntu + ROS2                │ Bare-metal firmware            │
│ Nav, Perception, Planning    │                               │
│             ──── CAN/UART ──▶│ Validates:                    │
│                cmd_vel        │ - Max velocity                │
│                               │ - Max acceleration            │
│             ◀── joint_fb ────│ - Workspace limits            │
│                               │ - Watchdog timeout            │
│ If compromised, safety       │ Rejects out-of-bounds cmds    │
│ controller STILL enforces    │ Runs on separate hardware     │
│ physical limits.             │ Does NOT run ROS2 or Linux    │
└──────────────────────────────┴───────────────────────────────┘
```

### Command Velocity Validation and Rate Limiting

Enforce at the driver level — last line of defense before actuators:

```python
# velocity_safety_gate.py
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist

class VelocitySafetyGate(Node):
    def __init__(self):
        super().__init__('velocity_safety_gate')
        self.declare_parameter('max_linear_vel', 1.0)   # m/s
        self.declare_parameter('max_angular_vel', 2.0)   # rad/s
        self.declare_parameter('max_linear_accel', 0.5)  # m/s^2
        self.declare_parameter('cmd_timeout_sec', 0.5)
        self.declare_parameter('max_cmd_rate_hz', 50.0)

        self.max_lin = self.get_parameter('max_linear_vel').value
        self.max_ang = self.get_parameter('max_angular_vel').value
        self.max_acc = self.get_parameter('max_linear_accel').value
        self.timeout = self.get_parameter('cmd_timeout_sec').value
        self.min_period = 1.0 / self.get_parameter('max_cmd_rate_hz').value

        self.last_cmd_time = self.get_clock().now()
        self.last_linear = 0.0
        self.last_pub_sec = 0.0

        self.sub = self.create_subscription(Twist, 'cmd_vel_raw', self.on_cmd, 10)
        self.pub = self.create_publisher(Twist, 'cmd_vel', 10)
        self.create_timer(0.1, self.watchdog_check)

    def on_cmd(self, msg: Twist):
        now = self.get_clock().now()
        now_sec = now.nanoseconds / 1e9
        if (now_sec - self.last_pub_sec) < self.min_period:
            return  # Rate limit exceeded — drop

        msg.linear.x = max(-self.max_lin, min(self.max_lin, msg.linear.x))
        msg.angular.z = max(-self.max_ang, min(self.max_ang, msg.angular.z))

        dt = (now - self.last_cmd_time).nanoseconds / 1e9
        if dt > 0:
            accel = abs(msg.linear.x - self.last_linear) / dt
            if accel > self.max_acc:
                sign = 1.0 if msg.linear.x > self.last_linear else -1.0
                msg.linear.x = self.last_linear + sign * self.max_acc * dt

        self.pub.publish(msg)
        self.last_cmd_time = now
        self.last_linear = msg.linear.x
        self.last_pub_sec = now_sec

    def watchdog_check(self):
        elapsed = (self.get_clock().now() - self.last_cmd_time).nanoseconds / 1e9
        if elapsed > self.timeout:
            self.pub.publish(Twist())  # No command → zero velocity
```

### Watchdog Independence from Application Software

```python
# Hardware watchdog — kernel resets system if not fed
import os

class HardwareWatchdog:
    """Uses /dev/watchdog. If not fed within timeout, kernel triggers reset."""
    def __init__(self):
        self.fd = os.open('/dev/watchdog', os.O_WRONLY)  # Starts countdown
    def feed(self):
        os.write(self.fd, b'\x00')  # Reset countdown
    def close(self):
        os.write(self.fd, b'V')     # Magic close — disarm gracefully
        os.close(self.fd)
```

```bash
# /etc/watchdog.conf
watchdog-device = /dev/watchdog
watchdog-timeout = 15
interval = 5
pidfile = /var/run/robot-safety-monitor.pid
max-load-1 = 24
```
