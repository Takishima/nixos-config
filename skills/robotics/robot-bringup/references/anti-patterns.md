# Robot Bringup Anti-Patterns

### 1. Sourcing setup.bash in .bashrc for systemd

**Problem:** systemd services do not load `~/.bashrc` or `~/.profile`. Environment variables set there are invisible to the service, causing ROS2 commands to fail with "command not found" or missing package errors.

```bash
# BAD: Relying on .bashrc for systemd services
# ~/.bashrc
source /opt/ros/humble/setup.bash  # systemd will never see this

# GOOD: Use EnvironmentFile in the service unit and source explicitly in ExecStart
# /etc/robot/ros2.env
ROS_DISTRO=humble
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# In the service unit:
# EnvironmentFile=/etc/robot/ros2.env
# ExecStart=/bin/bash -c 'source /opt/ros/${ROS_DISTRO}/setup.bash && ...'
```

### 2. No Startup Ordering

**Problem:** Starting all ROS2 nodes simultaneously causes race conditions. A navigation node may attempt to call a service that has not yet been advertised by the driver, leading to intermittent startup failures.

**Fix:** Use `After=` and `Requires=` in systemd units, or use a lifecycle manager to enforce ordered transitions:

```ini
# BAD: All services start in parallel with no ordering
[Unit]
Description=Robot Navigation
# No After= or Requires= directives

# GOOD: Explicit dependency chain
[Unit]
Description=Robot Navigation
After=robot-perception.service
Requires=robot-perception.service
```

### 3. Using Restart=always Without Rate Limiting

**Problem:** A service that crashes on startup (e.g., missing config file, hardware disconnected) will restart in a tight loop, consuming CPU and flooding the journal.

**Fix:** Use `StartLimitIntervalSec` and `StartLimitBurst` to cap restart attempts:

```ini
# BAD: Infinite restart loop
[Service]
Restart=always
RestartSec=1

# GOOD: Rate-limited restarts with failure notification
[Service]
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=120
StartLimitBurst=5
```

### 4. Relying on network.target Instead of network-online.target

**Problem:** `network.target` is reached as soon as the network configuration starts, not when connectivity is actually established. DDS discovery fails because the network interface does not have an IP address yet.

**Fix:** Use `network-online.target` and ensure `systemd-networkd-wait-online.service` or `NetworkManager-wait-online.service` is enabled:

```ini
# BAD: network.target does not guarantee connectivity
[Unit]
After=network.target

# GOOD: Wait for actual network connectivity
[Unit]
After=network-online.target
Wants=network-online.target
```

### 5. No Log Rotation

**Problem:** ROS2 log files in `~/.ros/log/` and journal entries grow without limit, eventually filling the disk on an embedded system with limited storage.

**Fix:** Configure logrotate for ROS2 log files and set journald size limits:

```bash
# BAD: No log management
# Logs in ~/.ros/log/ grow forever, disk fills up after weeks of operation

# GOOD: logrotate config + journald limits
# /etc/logrotate.d/ros2 (see Logging section above)
# /etc/systemd/journald.conf: SystemMaxUse=1G
```

### 6. Hardcoded Device Paths (/dev/ttyUSB0)

**Problem:** `/dev/ttyUSB0` can be assigned to any USB serial device depending on enumeration order. After a reboot, the IMU might become `/dev/ttyUSB1` and the motor controller `/dev/ttyUSB0`, reversing the mapping.

**Fix:** Use udev rules to create stable symlinks:

```yaml
# BAD: Hardcoded device path in ROS2 params
serial_port: "/dev/ttyUSB0"  # Which device is this? It changes on reboot!

# GOOD: Stable symlink via udev rule
serial_port: "/dev/robot/imu"  # Always points to the correct device
```

### 7. Running the Entire Stack as Root

**Problem:** Running ROS2 as root is a security risk and can cause permission issues with `rosbag2`, log files, and parameter persistence. A bug in a ROS2 node could damage the operating system.

**Fix:** Create a dedicated `robot` user and grant only the necessary device permissions via udev `GROUP` and `MODE` rules:

```bash
# BAD: Running as root
# ExecStart=/bin/bash -c 'source /opt/ros/humble/setup.bash && ros2 launch ...'
# (runs as root because no User= is specified)

# GOOD: Dedicated user with minimal privileges
# Create robot user
sudo useradd -r -m -s /bin/bash robot
sudo usermod -aG dialout,video,plugdev robot

# In the service unit:
# User=robot
# Group=robot

# udev rules grant device access to the robot user's groups:
# MODE="0666", GROUP="dialout"
```

### 8. No Graceful Shutdown Handler

**Problem:** When systemd sends `SIGTERM` or `SIGINT` to stop a ROS2 node, the node exits immediately without commanding zero velocity or engaging brakes. The robot may coast or continue moving with the last commanded velocity.

**Fix:** Register signal handlers or use rclpy's shutdown callback to command a safe state:

```python
# BAD: No shutdown handling, node just exits
def main():
    rclpy.init()
    node = MotorControlNode()
    rclpy.spin(node)
    # Robot is still moving with last commanded velocity!

# GOOD: Shutdown handler commands safe state
def main():
    rclpy.init()
    node = MotorControlNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.command_zero_velocity()
        node.engage_brakes()
        node.destroy_node()
        rclpy.shutdown()
```
