# The Robot Bringup Stack

A production robot bringup follows a layered startup sequence from hardware initialization through application-level nodes. Each layer depends on the one below it.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        APPLICATION LAYER                            │
│  Navigation, manipulation, mission planning, HRI                    │
├─────────────────────────────────────────────────────────────────────┤
│                        PERCEPTION LAYER                             │
│  Object detection, SLAM, point cloud filtering, sensor fusion       │
├─────────────────────────────────────────────────────────────────────┤
│                         DRIVER LAYER                                │
│  Camera drivers, LiDAR drivers, motor controllers, IMU              │
├─────────────────────────────────────────────────────────────────────┤
│                        HARDWARE LAYER                               │
│  udev rules, device enumeration, USB reset, firmware check          │
├─────────────────────────────────────────────────────────────────────┤
│                      ROS2 ENVIRONMENT                               │
│  Source workspace, set RMW, ROS_DOMAIN_ID, DDS config               │
├─────────────────────────────────────────────────────────────────────┤
│                    SYSTEMD TARGETS & SERVICES                       │
│  network-online.target → robot-hw.target → robot-bringup.target     │
├─────────────────────────────────────────────────────────────────────┤
│                      LINUX BOOT (systemd)                           │
│  BIOS/UEFI → GRUB → kernel → systemd init                          │
├─────────────────────────────────────────────────────────────────────┤
│                         HARDWARE BOOT                               │
│  Power supply, onboard computer, peripherals                        │
└─────────────────────────────────────────────────────────────────────┘
```
