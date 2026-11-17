# Display Forwarding

### X11 Forwarding

```yaml
services:
  rviz:
    image: my_robot:dev
    command: ros2 run rviz2 rviz2
    environment:
      - DISPLAY=${DISPLAY:-:0}                   # Forward host display
      - QT_X11_NO_MITSHM=1                       # Disable MIT-SHM (crashes in Docker)
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw          # X11 socket
      - ${HOME}/.Xauthority:/root/.Xauthority:ro  # Auth cookie
    network_mode: host
```

```bash
# Allow local Docker containers to access the X server
xhost +local:docker
# More secure variant:
xhost +SI:localuser:$(whoami)
```

### Wayland Forwarding

```yaml
services:
  rviz:
    image: my_robot:dev
    command: ros2 run rviz2 rviz2
    environment:
      - WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
      - XDG_RUNTIME_DIR=/run/user/1000
      - QT_QPA_PLATFORM=wayland
    volumes:
      - ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:/run/user/1000/${WAYLAND_DISPLAY}:rw
```

### Headless Rendering

For CI/CD or remote machines without a physical display:

```bash
# Run rviz2 headless with Xvfb for screenshot capture or testing
docker run --rm my_robot:dev bash -c '
  apt-get update && apt-get install -y xvfb mesa-utils &&
  Xvfb :99 -screen 0 1920x1080x24 &
  export DISPLAY=:99
  source /opt/ros/humble/setup.bash
  ros2 run rviz2 rviz2 -d /config/test.rviz --screenshot /output/frame.png
'
```
