# Package Structure (ROS2)

```
my_robot_pkg/
├── CMakeLists.txt              # Or setup.py for pure Python
├── package.xml
├── my_robot_pkg/               # Python module (same name as package)
│   ├── __init__.py
│   ├── perception_node.py
│   └── utils/
│       └── transforms.py
├── src/                        # C++ source
│   └── perception_component.cpp
├── include/my_robot_pkg/       # C++ headers
│   └── perception_component.hpp
├── config/
│   ├── robot_params.yaml
│   └── cyclonedds.xml
├── launch/
│   ├── robot.launch.py
│   └── perception.launch.py
├── msg/
│   └── Detection.msg
├── srv/
│   └── GetPose.srv
├── action/
│   └── PickPlace.action
├── rviz/
│   └── robot.rviz
├── urdf/
│   └── robot.urdf.xacro
└── test/
    ├── test_perception.py      # pytest
    └── test_integration.py     # launch_testing
```
