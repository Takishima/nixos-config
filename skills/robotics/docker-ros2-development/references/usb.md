# USB Device Passthrough

### Cameras and Serial Devices

```yaml
services:
  camera_driver:
    image: my_robot_driver:latest
    devices:
      - /dev/video0:/dev/video0        # USB camera (V4L2)
      - /dev/video1:/dev/video1
    group_add:
      - video                          # Access /dev/videoN without root

  motor_driver:
    image: my_robot_driver:latest
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0      # USB-serial motor controller
      - /dev/ttyACM0:/dev/ttyACM0      # Arduino/Teensy
    group_add:
      - dialout                        # Access serial ports without root
```

### Udev Rules Inside Containers

Create stable device symlinks on the host so container paths remain consistent regardless of USB enumeration order.

```bash
# /etc/udev/rules.d/99-robot-devices.rules (host-side)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="robot/motor_controller"
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="robot/lidar"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="0825", SYMLINK+="robot/camera"
```

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```

```yaml
services:
  driver:
    devices:
      - /dev/robot/motor_controller:/dev/ttyMOTOR   # Stable symlink
      - /dev/robot/lidar:/dev/ttyLIDAR
      - /dev/robot/camera:/dev/video0
```

### Dynamic Device Attachment

For devices plugged in after the container starts:

```yaml
services:
  driver:
    # Option 1: privileged (use only when necessary)
    privileged: true
    volumes:
      - /dev:/dev

    # Option 2: cgroup device rules (more secure)
    # device_cgroup_rules:
    #   - 'c 188:* rmw'                  # USB-serial (major 188)
    #   - 'c 81:* rmw'                   # Video devices (major 81)
```
