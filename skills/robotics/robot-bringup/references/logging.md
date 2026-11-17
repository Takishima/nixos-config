# Logging and Log Rotation

### ROS2 Log Configuration

```bash
# Set log level via environment
export RCUTILS_LOGGING_USE_STDOUT=0          # Log to stderr (captured by journald)
export RCUTILS_COLORIZED_OUTPUT=0            # Disable color codes in log files
export RCUTILS_CONSOLE_OUTPUT_FORMAT="[{severity}] [{time}] [{name}]: {message}"

# Set log level at runtime
ros2 run my_pkg my_node --ros-args --log-level debug
ros2 run my_pkg my_node --ros-args --log-level my_node:=debug

# Set log level via parameter (Humble+)
ros2 param set /my_node use_sim_time false
ros2 service call /my_node/set_logger_level rcl_interfaces/srv/SetLoggerLevel \
  "{logger_name: 'my_node', level: 10}"
```

### journald Configuration for ROS2 Services

```ini
# /etc/systemd/journald.conf.d/robot.conf
[Journal]
# Persist logs across reboots
Storage=persistent

# Limit total journal size to 1 GB
SystemMaxUse=1G

# Limit per-file size to 100 MB
SystemMaxFileSize=100M

# Keep logs for 30 days
MaxRetentionSec=30day

# Rate limit: allow bursts during startup
RateLimitIntervalSec=10s
RateLimitBurst=10000

# Forward to syslog for remote logging
ForwardToSyslog=yes
```

```bash
# View logs for a specific robot service
journalctl -u robot-drivers.service -f

# View logs since last boot
journalctl -u robot-bringup.service -b

# View logs with priority filtering (error and above)
journalctl -u robot-bringup.service -p err

# Export logs for analysis
journalctl -u robot-bringup.service --since "2024-01-01" --output=json > logs.json
```

### logrotate for ROS2 Log Files

ROS2 writes log files to `~/.ros/log/` by default, or to `$ROS_LOG_DIR`. These grow unbounded without rotation.

```ini
# /etc/logrotate.d/ros2
/var/log/ros2/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 robot robot
    maxsize 100M
    dateext
    dateformat -%Y%m%d
    postrotate
        # Notify ROS2 nodes to reopen log files (if using file logging)
        systemctl kill --signal=HUP robot-bringup.service 2>/dev/null || true
    endscript
}

/home/robot/.ros/log/**/*.log {
    daily
    rotate 3
    compress
    missingok
    notifempty
    maxsize 50M
}
```

### Structured Logging for Production

```python
import json
import logging
from rclpy.node import Node


class StructuredLogger:
    """Wraps ROS2 logger with structured JSON output for production monitoring."""

    def __init__(self, node: Node):
        self.node = node
        self.logger = node.get_logger()

    def log_event(self, event_type: str, level: str = 'info', **kwargs):
        """Log a structured event with key-value metadata."""
        entry = {
            'event': event_type,
            'node': self.node.get_name(),
            'namespace': self.node.get_namespace(),
            'stamp': self.node.get_clock().now().nanoseconds,
            **kwargs,
        }
        message = json.dumps(entry)
        getattr(self.logger, level)(message)


# Usage in a node:
# self.slog = StructuredLogger(self)
# self.slog.log_event('detection', count=5, latency_ms=12.3)
# self.slog.log_event('motor_fault', level='error', motor_id=2, code=0x0A)
```
