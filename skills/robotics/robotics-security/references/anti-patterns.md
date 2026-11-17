# Robotics Security Anti-Patterns

### 1. Unauthenticated /cmd_vel

**Problem:** Default ROS2 lets any DDS participant publish to `/cmd_vel`. One command from any machine on the LAN moves the robot.

```bash
# BAD: anyone on the network can do this
ros2 topic pub /cmd_vel geometry_msgs/Twist "{linear: {x: 999.0}}"
```

**Fix:** SROS2 with `Enforce`. Restrict `/cmd_vel` publish to authorized enclaves. Velocity safety gate as secondary check.

```bash
# GOOD: unauthorized publish rejected at DDS layer
export ROS_SECURITY_ENABLE=true
export ROS_SECURITY_STRATEGY=Enforce
```

### 2. Shared SSH Keys Across Robot Fleet

**Problem:** One key compromised = entire fleet compromised.

```bash
# BAD: same key for all robots
ssh-copy-id -i ~/.ssh/fleet_key.pub robot@robot-001
ssh-copy-id -i ~/.ssh/fleet_key.pub robot@robot-002
```

**Fix:** Unique key per robot. Use SSH CA with short-lived certificates.

```bash
# GOOD: SSH CA issues 8-hour certs per session
ssh-keygen -s /etc/ssh/ca_key -I "session-$(date +%s)" -n robot-admin -V +8h ~/.ssh/id_ed25519.pub
```

### 3. Running All Nodes as Root

**Problem:** Any compromised node = full root access to the system.

```bash
# BAD:
sudo ros2 launch my_robot bringup.launch.py
```

**Fix:** Run as unprivileged user. Use udev rules for hardware access instead of root.

```bash
# GOOD:
sudo -u robot ros2 launch my_robot bringup.launch.py
# /etc/udev/rules.d/99-robot.rules:
# SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", MODE="0660", GROUP="robot"
```

### 4. No Network Segmentation

**Problem:** All traffic on one flat network. Compromised IP camera reaches motor controller.

**Fix:** VLAN segmentation with inter-VLAN firewall rules. See Network Hardening section.

```bash
# BAD: everything on 192.168.1.0/24

# GOOD: VLAN 10 control (wired), VLAN 20 data, VLAN 30 mgmt (jump host)
```

### 5. Hardcoded Credentials in Launch Files

**Problem:** Credentials in version control exposed to repo access, CI logs, Docker layers.

```yaml
# BAD: in params.yaml tracked by git
cloud_connector:
  ros__parameters:
    aws_access_key: "AKIAIOSFODNN7EXAMPLE"  # pragma: allowlist secret
```

**Fix:** Environment variables from protected files. Scan repos with `gitleaks`.

```bash
# GOOD: secrets injected at runtime via systemd EnvironmentFile
gitleaks detect --source . --verbose  # Pre-commit check
```

### 6. E-Stop Over Network

**Problem:** Software e-stop over ROS2 as the **only** safety mechanism. Network down = no stop.

```python
# BAD: sole e-stop is a ROS2 topic subscriber
self.create_subscription(Bool, '/e_stop', self.software_estop, 10)
```

**Fix:** Hardwired e-stop circuit. Software e-stop is an additional layer, never the sole path.

### 7. No Certificate Rotation

**Problem:** SROS2 certs generated once and never rotated. Compromised key = permanent access.

**Fix:** Monthly automated rotation via cron. Explicit validity periods in permissions XML. Emergency rotation capability via fleet management.

### 8. Disabling Security for Convenience

**Problem:** SROS2 disabled in production because "too hard" or "adds latency." Most common robotics security failure.

```bash
# BAD: "temporary" becomes permanent
export ROS_SECURITY_ENABLE=false
```

**Fix:** Security enabled in CI/CD from day one. Tests must pass with `Enforce`.

```bash
# GOOD: CI enforces security
export ROS_SECURITY_ENABLE=true
export ROS_SECURITY_STRATEGY=Enforce
ros2 launch my_robot test.launch.py  # Must pass with security on
```
