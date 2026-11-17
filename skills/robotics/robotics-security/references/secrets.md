# Secrets Management

### No Hardcoded Credentials

```python
# BAD:
class FleetClient:
    def __init__(self):
        self.api_key = "sk-live-abc123xyz789"
```

```python
# GOOD:
import os
class FleetClient:
    def __init__(self):
        self.api_key = os.environ['FLEET_API_KEY']
```

```yaml
# BAD: credentials in params.yaml tracked by git
fleet_manager:
  ros__parameters:
    aws_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # pragma: allowlist secret
```

```yaml
# GOOD: reference environment variables
fleet_manager:
  ros__parameters:
    aws_secret_key: "$(env AWS_SECRET_KEY)"
```

### Environment-Based Secrets for ROS2 Nodes

```ini
# /etc/systemd/system/robot-nav.service
[Service]
User=robot
Group=robot
EnvironmentFile=/etc/robot/secrets.env
ExecStart=/opt/ros/humble/bin/ros2 launch my_robot nav.launch.py
Restart=always
```

```bash
# /etc/robot/secrets.env
FLEET_API_KEY=sk-live-actual-key-here
ROS_SECURITY_KEYSTORE=/opt/robot/sros2_keystore

# Lock it down
sudo chown root:robot /etc/robot/secrets.env
sudo chmod 640 /etc/robot/secrets.env
```

### Certificate Rotation Patterns

```bash
#!/bin/bash
# rotate_certs.sh — run via cron monthly
set -euo pipefail
KEYSTORE="/opt/robot/sros2_keystore"
cp -r "${KEYSTORE}" "${KEYSTORE}_backup_$(date +%Y%m%d)"

for enclave in motor_controller navigation camera_driver teleop; do
    ros2 security create_enclave "${KEYSTORE}" "/my_robot/${enclave}"
done
sudo systemctl restart robot-*.service
echo "Certificates rotated at $(date)"
```

```bash
# /etc/cron.d/robot-cert-rotation
0 3 1 * * root /opt/robot/scripts/rotate_certs.sh >> /var/log/cert-rotation.log 2>&1
```

### File Permissions for Keystores

```bash
sudo chown -R root:robot /opt/robot/sros2_keystore
sudo find /opt/robot/sros2_keystore -type d -exec chmod 750 {} \;
sudo find /opt/robot/sros2_keystore -type f -exec chmod 640 {} \;
# CA private key — root only
sudo chmod 600 /opt/robot/sros2_keystore/private/ca.key.pem
sudo chown root:root /opt/robot/sros2_keystore/private/ca.key.pem
```
