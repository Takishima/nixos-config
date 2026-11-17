# udev Rules for Deterministic Device Naming

### Writing udev Rules for Cameras

USB cameras can enumerate in any order on boot, causing `/dev/video0` to be unpredictable. Use udev rules to assign stable symlinks based on device attributes.

```bash
# /etc/udev/rules.d/99-robot-cameras.rules
# Assign stable device names based on USB port path (physical location).
# Find attributes with: udevadm info --name=/dev/video0 --attribute-walk

# Front camera: USB hub port 1, interface 0 (video capture)
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="1234", ATTRS{idProduct}=="5678", \
  KERNELS=="1-1.2:1.0", ATTR{index}=="0", \
  SYMLINK+="robot/camera_front", MODE="0666", GROUP="video"

# Rear camera: USB hub port 2, interface 0 (video capture)
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="1234", ATTRS{idProduct}=="5678", \
  KERNELS=="1-1.3:1.0", ATTR{index}=="0", \
  SYMLINK+="robot/camera_rear", MODE="0666", GROUP="video"

# Depth camera (RealSense): by serial number
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0b3a", \
  ATTRS{serial}=="123456789", ATTR{index}=="0", \
  SYMLINK+="robot/camera_depth", MODE="0666", GROUP="video"
```

### Writing udev Rules for Serial Devices

Serial devices (IMU, motor controller, GPS) also need stable names since `/dev/ttyUSB*` numbering is non-deterministic.

```bash
# /etc/udev/rules.d/99-robot-serial.rules
# IMU on FTDI serial adapter (identified by serial number)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", \
  ATTRS{serial}=="AB0CDEFG", \
  SYMLINK+="robot/imu", MODE="0666", GROUP="dialout"

# Motor controller on USB port path
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", \
  KERNELS=="1-1.4:1.0", \
  SYMLINK+="robot/motor_controller", MODE="0666", GROUP="dialout"

# GPS receiver
SUBSYSTEM=="tty", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a7", \
  SYMLINK+="robot/gps", MODE="0666", GROUP="dialout"

# LiDAR (CP2102 adapter)
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", \
  ATTRS{serial}=="0001", \
  SYMLINK+="robot/lidar", MODE="0666", GROUP="dialout"
```

### Reloading and Testing

```bash
# Reload udev rules without rebooting
sudo udevadm control --reload-rules
sudo udevadm trigger

# Test a rule against a specific device
sudo udevadm test $(udevadm info --query=path --name=/dev/ttyUSB0)

# View all attributes for a device (use to find idVendor, serial, etc.)
udevadm info --name=/dev/ttyUSB0 --attribute-walk

# Monitor udev events in real time (plug/unplug devices to see events)
udevadm monitor --subsystem-match=tty --property
```
