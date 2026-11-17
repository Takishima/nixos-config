# systemd Service Units for ROS2

### Basic ROS2 Service Unit

Place service files in `/etc/systemd/system/`. This template starts a ROS2 launch file as a long-running service with watchdog support.

```ini
# /etc/systemd/system/robot-bringup.service
[Unit]
Description=Robot ROS2 Bringup Stack
Documentation=https://github.com/my-org/my-robot
After=network-online.target robot-hw.target
Wants=network-online.target
Requires=robot-hw.target

[Service]
Type=notify
User=robot
Group=robot
WorkingDirectory=/home/robot

# Load ROS2 environment variables from a dedicated env file
EnvironmentFile=/etc/robot/ros2.env

# Pre-start check: verify critical devices exist
ExecStartPre=/usr/local/bin/robot-device-check.sh

# Start the ROS2 launch file via bash so we can source the workspace
ExecStart=/bin/bash -c '\
  source /opt/ros/${ROS_DISTRO}/setup.bash && \
  source /home/robot/ros2_ws/install/setup.bash && \
  exec ros2 launch my_robot_bringup bringup.launch.py'

# Graceful shutdown: send SIGINT first (Ctrl+C equivalent for ROS2)
ExecStop=/bin/kill -INT $MAINPID
TimeoutStopSec=30

# Restart on failure, but not on clean exit
Restart=on-failure
RestartSec=5

# systemd watchdog: service must call sd_notify(WATCHDOG=1) within this interval
WatchdogSec=30

# Process management
KillMode=mixed
KillSignal=SIGINT
FinalKillSignal=SIGKILL
TimeoutStartSec=60

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=robot-bringup

[Install]
WantedBy=multi-user.target
```

### Environment Setup in systemd

Store environment variables in a dedicated file rather than sourcing .bashrc (which is not loaded by systemd).

```bash
# /etc/robot/ros2.env
# ROS2 distribution
ROS_DISTRO=humble

# DDS middleware selection
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Domain isolation: unique per robot to avoid cross-talk
ROS_DOMAIN_ID=42

# CycloneDDS configuration file path
CYCLONEDDS_URI=file:///etc/robot/cyclonedds.xml

# Disable localhost-only mode for multi-machine setups
ROS_LOCALHOST_ONLY=0

# Logging configuration
ROS_LOG_DIR=/var/log/ros2
RCUTILS_LOGGING_USE_STDOUT=0
RCUTILS_COLORIZED_OUTPUT=0

# Robot-specific configuration
ROBOT_NAME=my_robot_01
ROBOT_CONFIG_DIR=/etc/robot/config
```

### Dependencies Between Services

Split the robot stack into multiple systemd services with explicit ordering. This allows independent restart of layers and clearer failure isolation.

```ini
# /etc/systemd/system/robot-drivers.service
[Unit]
Description=Robot Hardware Drivers (cameras, LiDAR, IMU, motors)
After=network-online.target robot-hw.target
Wants=network-online.target
Requires=robot-hw.target

[Service]
Type=notify
User=robot
EnvironmentFile=/etc/robot/ros2.env
ExecStart=/bin/bash -c '\
  source /opt/ros/${ROS_DISTRO}/setup.bash && \
  source /home/robot/ros2_ws/install/setup.bash && \
  exec ros2 launch my_robot_bringup drivers.launch.py'
Restart=on-failure
RestartSec=5
WatchdogSec=30
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=20
StandardOutput=journal
SyslogIdentifier=robot-drivers

[Install]
WantedBy=robot-bringup.target
```

```ini
# /etc/systemd/system/robot-perception.service
[Unit]
Description=Robot Perception Stack (SLAM, detection, sensor fusion)
After=robot-drivers.service
Requires=robot-drivers.service
PartOf=robot-drivers.service

[Service]
Type=notify
User=robot
EnvironmentFile=/etc/robot/ros2.env
ExecStart=/bin/bash -c '\
  source /opt/ros/${ROS_DISTRO}/setup.bash && \
  source /home/robot/ros2_ws/install/setup.bash && \
  exec ros2 launch my_robot_bringup perception.launch.py'
Restart=on-failure
RestartSec=5
WatchdogSec=30
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=20
StandardOutput=journal
SyslogIdentifier=robot-perception

[Install]
WantedBy=robot-bringup.target
```

```ini
# /etc/systemd/system/robot-application.service
[Unit]
Description=Robot Application Layer (navigation, planning, HRI)
After=robot-perception.service
Requires=robot-perception.service
PartOf=robot-perception.service

[Service]
Type=notify
User=robot
EnvironmentFile=/etc/robot/ros2.env
ExecStart=/bin/bash -c '\
  source /opt/ros/${ROS_DISTRO}/setup.bash && \
  source /home/robot/ros2_ws/install/setup.bash && \
  exec ros2 launch my_robot_bringup application.launch.py'
Restart=on-failure
RestartSec=10
WatchdogSec=30
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=20
StandardOutput=journal
SyslogIdentifier=robot-application

[Install]
WantedBy=robot-bringup.target
```

### Restart Policies and Failure Recovery

Configure rate limiting to prevent restart loops when a service is fundamentally broken (e.g., missing device, configuration error).

```ini
# Add to the [Service] section of any robot service
Restart=on-failure
RestartSec=5

# Allow at most 5 restart attempts within 120 seconds
StartLimitIntervalSec=120
StartLimitBurst=5

# Ramp up restart delay to avoid thrashing
# RestartSec can also be set dynamically via drop-in overrides:
#   RestartSec=5   (first few retries, fast recovery)
#   After StartLimitBurst is hit, the unit enters failed state
#   Use systemctl reset-failed robot-drivers.service to retry

# On final failure, trigger an alert
OnFailure=robot-alert@%n.service
```

### Resource Limits and cgroups

Constrain resource usage to prevent a runaway node from starving the rest of the system.

```ini
# Add to the [Service] section
# Limit memory to 2 GB (hard kill at 2.5 GB)
MemoryMax=2G
MemoryHigh=1800M

# Limit CPU to 300% (3 cores on a multi-core system)
CPUQuota=300%

# Set real-time scheduling priority for time-critical drivers
# Requires the user to have rtprio permissions in /etc/security/limits.d/
Nice=-5
IOSchedulingClass=realtime
IOSchedulingPriority=0

# Restrict filesystem access
ProtectHome=read-only
ProtectSystem=strict
ReadWritePaths=/var/log/ros2 /tmp
PrivateTmp=true
```
