# Robot Bringup Checklist

1. **udev rules written and tested** for all USB devices (cameras, LiDARs, serial adapters) with stable symlinks under `/dev/robot/`
1. **systemd service units created** for each layer (drivers, perception, application) with correct `After=`/`Requires=` ordering
1. **ROS2 environment file** (`/etc/robot/ros2.env`) configured with `ROS_DISTRO`, `RMW_IMPLEMENTATION`, `ROS_DOMAIN_ID`, and `CYCLONEDDS_URI`
1. **CycloneDDS or FastDDS XML** configured with explicit peer list for multi-machine discovery
1. **Launch files layered and composable** with conditional arguments for sim/real and robot variants
1. **Health check scripts** written for `ExecStartPre` to verify device presence before starting drivers
1. **Watchdog integration** configured: `WatchdogSec` in service units and `sd_notify(WATCHDOG=1)` in the ROS2 process
1. **Heartbeat monitor node** deployed to detect node failures and trigger safe stop
1. **Graceful shutdown handlers** registered in all actuator nodes (zero velocity, engage brakes on `SIGINT`/`SIGTERM`)
1. **Log rotation configured** via logrotate for `$ROS_LOG_DIR` and journald `SystemMaxUse` limits
1. **Restart policies rate-limited** with `StartLimitIntervalSec` and `StartLimitBurst` to prevent restart loops
1. **Resource limits set** via `MemoryMax`, `CPUQuota` to prevent runaway nodes from starving the system
1. **Network and firewall configured** with static IPs, DDS port rules, and `ROS_LOCALHOST_ONLY` set correctly
1. **Full boot test performed** from power-off to autonomous operation, verifying service ordering and recovery from simulated failures
