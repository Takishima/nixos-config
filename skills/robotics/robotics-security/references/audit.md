# Audit and Monitoring

### Security Logging for ROS2

```python
# topic_auditor.py — logs publications on sensitive topics
import rclpy, json, time
from rclpy.node import Node
from geometry_msgs.msg import Twist

class TopicAuditor(Node):
    def __init__(self):
        super().__init__('topic_auditor')
        self.log = open('/var/log/ros2_audit.jsonl', 'a')
        self.create_subscription(Twist, '/cmd_vel', self.audit_cmd_vel, 10)

    def audit_cmd_vel(self, msg: Twist):
        record = {'ts': time.time(), 'topic': '/cmd_vel',
                  'lin_x': msg.linear.x, 'ang_z': msg.angular.z}
        self.log.write(json.dumps(record) + '\n')
        self.log.flush()
        if abs(msg.linear.x) > 0.8 or abs(msg.angular.z) > 1.5:
            self.get_logger().warn(f'HIGH VEL: lin={msg.linear.x:.2f} ang={msg.angular.z:.2f}')
```

### Intrusion Detection on Command Topics

```python
# cmd_vel_anomaly_detector.py
import numpy as np
from collections import deque
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist

class CmdVelAnomalyDetector(Node):
    def __init__(self):
        super().__init__('cmd_vel_anomaly_detector')
        self.window = deque(maxlen=100)
        self.alert_pub = self.create_publisher(Twist, '/security/cmd_vel_alert', 10)
        self.create_subscription(Twist, '/cmd_vel', self.on_cmd, 10)

    def on_cmd(self, msg: Twist):
        self.window.append((msg.linear.x, msg.angular.z))
        if len(self.window) < 20:
            return
        vels = np.array(list(self.window))
        z_scores = np.abs((np.array([msg.linear.x, msg.angular.z]) - vels.mean(0)) / (vels.std(0) + 1e-6))
        if np.any(z_scores > 3.0):
            self.get_logger().error(f'ANOMALY: lin={msg.linear.x:.3f} ang={msg.angular.z:.3f} z={z_scores}')
            self.alert_pub.publish(msg)
```

### auditd Rules for Robot Systems

```bash
# /etc/audit/rules.d/robot-security.rules
-w /opt/robot/sros2_keystore/ -p rwxa -k robot_keystore
-w /etc/robot/ -p wa -k robot_config
-w /home/robot-admin/.ssh/ -p wa -k ssh_keys
-w /opt/robot/firmware/ -p rwxa -k firmware_access
-w /etc/systemd/system/robot- -p wa -k robot_services
-a always,exit -F arch=b64 -F euid=0 -S execve -k root_commands
-w /dev/bus/usb/ -p rwxa -k usb_access
-w /etc/netplan/ -p wa -k network_config
-w /etc/iptables/ -p wa -k firewall_config
-w /usr/bin/docker -p x -k docker_exec
```

```bash
sudo auditctl -R /etc/audit/rules.d/robot-security.rules
sudo systemctl enable --now auditd
sudo ausearch -k robot_keystore --start today
```
