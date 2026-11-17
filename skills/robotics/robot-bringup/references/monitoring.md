# Remote Monitoring and Debugging

### SSH Tunneling for ROS2 Topics

Forward DDS traffic over SSH when direct network connectivity is not available (e.g., robot is on a cellular connection).

```bash
#!/bin/bash
# ssh-ros2-tunnel.sh
# Creates an SSH tunnel for ROS2 DDS traffic between local machine and robot.
# Usage: ./ssh-ros2-tunnel.sh robot@10.0.0.10

set -euo pipefail

ROBOT_HOST="${1:?Usage: $0 robot@host}"
DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
BASE_PORT=$((7400 + 250 * DOMAIN_ID))

echo "Setting up SSH tunnel for ROS2 domain $DOMAIN_ID (ports $BASE_PORT-$((BASE_PORT + 200)))"

# Forward DDS discovery and data ports
ssh -N \
  -L ${BASE_PORT}:localhost:${BASE_PORT} \
  -L $((BASE_PORT + 1)):localhost:$((BASE_PORT + 1)) \
  -L $((BASE_PORT + 10)):localhost:$((BASE_PORT + 10)) \
  -L $((BASE_PORT + 11)):localhost:$((BASE_PORT + 11)) \
  "$ROBOT_HOST" &

SSH_PID=$!
echo "SSH tunnel PID: $SSH_PID"

# Set environment for local ROS2 to use localhost-only discovery
export ROS_LOCALHOST_ONLY=1
echo "Run: export ROS_LOCALHOST_ONLY=1"
echo "Then use ros2 topic list, ros2 topic echo, etc."
echo "Press Ctrl+C to close tunnel."

wait $SSH_PID
```

### Remote journalctl and Service Management

```bash
# View live robot logs remotely
ssh robot@10.0.0.10 'journalctl -u robot-bringup.service -f'

# Check service status
ssh robot@10.0.0.10 'systemctl status robot-drivers.service robot-perception.service'

# Restart a single layer without rebooting
ssh robot@10.0.0.10 'sudo systemctl restart robot-perception.service'

# View boot-time service ordering
ssh robot@10.0.0.10 'systemd-analyze blame | head -20'

# Check for failed services
ssh robot@10.0.0.10 'systemctl --failed'

# Stream structured logs as JSON
ssh robot@10.0.0.10 'journalctl -u robot-bringup.service -o json --follow'
```

### Deploying Updates via SSH

```bash
#!/bin/bash
# deploy-to-robot.sh
# Build locally, copy to robot, and restart services.
# Usage: ./deploy-to-robot.sh robot@10.0.0.10

set -euo pipefail

ROBOT_HOST="${1:?Usage: $0 robot@host}"
WORKSPACE="/home/robot/ros2_ws"

echo "=== Building workspace locally ==="
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release --packages-select my_robot_bringup

echo "=== Syncing to robot ==="
rsync -avz --delete \
  --exclude='build/' --exclude='log/' \
  src/ "${ROBOT_HOST}:${WORKSPACE}/src/"

echo "=== Building on robot ==="
ssh "$ROBOT_HOST" "cd ${WORKSPACE} && \
  source /opt/ros/\${ROS_DISTRO}/setup.bash && \
  colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release"

echo "=== Restarting robot services ==="
ssh "$ROBOT_HOST" 'sudo systemctl restart robot-bringup.target'

echo "=== Checking service status ==="
ssh "$ROBOT_HOST" 'sleep 3 && systemctl status robot-bringup.target --no-pager'

echo "Deploy complete."
```
