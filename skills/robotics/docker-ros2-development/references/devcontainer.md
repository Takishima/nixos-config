# Dev Container Configuration

```json
// .devcontainer/devcontainer.json
{
  "name": "ROS2 Humble Dev",
  "build": {
    "dockerfile": "../Dockerfile",
    "target": "dev",
    "args": { "ROS_DISTRO": "humble" }
  },
  "runArgs": [
    "--network=host", "--ipc=host", "--pid=host",
    "--privileged", "--gpus", "all",
    "-e", "DISPLAY=${localEnv:DISPLAY}",
    "-e", "QT_X11_NO_MITSHM=1",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix:rw",
    "-v", "/dev:/dev"
  ],
  "workspaceMount": "source=${localWorkspaceFolder},target=/ros2_ws/src,type=bind",
  "workspaceFolder": "/ros2_ws",
  "mounts": [
    "source=ros2-build-vol,target=/ros2_ws/build,type=volume",
    "source=ros2-install-vol,target=/ros2_ws/install,type=volume",
    "source=ros2-log-vol,target=/ros2_ws/log,type=volume",
    "source=ros2-ccache-vol,target=/ccache,type=volume"
  ],
  "containerEnv": {
    "ROS_DISTRO": "humble",
    "RMW_IMPLEMENTATION": "rmw_cyclonedds_cpp",
    "CCACHE_DIR": "/ccache",
    "RCUTILS_COLORIZED_OUTPUT": "1"
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-iot.vscode-ros",
        "ms-vscode.cpptools",
        "ms-python.python",
        "ms-vscode.cmake-tools",
        "smilerobotics.urdf",
        "redhat.vscode-xml",
        "redhat.vscode-yaml"
      ],
      "settings": {
        "ros.distro": "humble",
        "python.defaultInterpreterPath": "/usr/bin/python3",
        "C_Cpp.default.compileCommands": "/ros2_ws/build/compile_commands.json",
        "cmake.configureOnOpen": false
      }
    }
  },
  "postCreateCommand": "sudo apt-get update && rosdep update && rosdep install --from-paths src --ignore-src -r -y",
  "remoteUser": "rosuser"
}
```
