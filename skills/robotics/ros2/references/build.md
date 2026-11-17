# Build System

### Workspace Setup and colcon

```bash
# Create a ROS2 workspace
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws

# Clone packages into src/
cd src
git clone https://github.com/org/my_robot_pkg.git
cd ..

# Install dependencies declared in package.xml files
sudo apt update
rosdep update
rosdep install --from-paths src --ignore-src -y

# Build the workspace
source /opt/ros/humble/setup.bash   # Source the ROS2 underlay FIRST
colcon build

# Source the workspace overlay
source install/setup.bash
```

**Essential colcon flags**:

```bash
# Build only specific packages (faster iteration)
colcon build --packages-select my_pkg

# Build a package and all its dependencies
colcon build --packages-up-to my_pkg

# Symlink Python files instead of copying (edit without rebuild)
colcon build --symlink-install

# Parallel jobs (default = nproc, lower if running out of RAM)
colcon build --parallel-workers 4

# Pass CMake args to all packages
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# Clean build (remove build/ install/ log/ and rebuild)
rm -rf build/ install/ log/
colcon build

# Build with compiler warnings as errors (CI)
colcon build --cmake-args -DCMAKE_CXX_FLAGS="-Wall -Werror"

# Show build output in real-time (useful for debugging build failures)
colcon build --event-handlers console_direct+
```

### Build Types: ament_cmake vs ament_python

Choose based on your package language:

```
ament_cmake     — C++ packages, mixed C++/Python packages, packages with custom msgs
ament_python    — Pure Python packages (no C++, no custom messages)
```

### package.xml — Declaring Dependencies

```xml
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd"
            schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>my_robot_pkg</name>
  <version>0.1.0</version>
  <description>My robot perception package</description>
  <maintainer email="dev@example.com">Dev Name</maintainer>
  <license>Apache-2.0</license>

  <!-- Build tool — determines build type -->
  <buildtool_depend>ament_cmake</buildtool_depend>
  <!-- For pure Python: <buildtool_depend>ament_python</buildtool_depend> -->

  <!-- Build-time dependencies (headers, CMake modules) -->
  <build_depend>rclcpp</build_depend>
  <build_depend>sensor_msgs</build_depend>
  <build_depend>OpenCV</build_depend>

  <!-- Runtime dependencies -->
  <exec_depend>rclcpp</exec_depend>
  <exec_depend>sensor_msgs</exec_depend>
  <exec_depend>rclpy</exec_depend>

  <!-- Shortcut: depend = build_depend + exec_depend -->
  <depend>rclcpp</depend>
  <depend>sensor_msgs</depend>
  <depend>geometry_msgs</depend>
  <depend>tf2_ros</depend>
  <depend>cv_bridge</depend>

  <!-- For custom message generation -->
  <build_depend>rosidl_default_generators</build_depend>
  <exec_depend>rosidl_default_runtime</exec_depend>
  <member_of_group>rosidl_interface_packages</member_of_group>

  <!-- Test dependencies -->
  <test_depend>ament_lint_auto</test_depend>
  <test_depend>ament_cmake_pytest</test_depend>
  <test_depend>launch_testing_ament_cmake</test_depend>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
```

### CMakeLists.txt — ament_cmake Package

```cmake
cmake_minimum_required(VERSION 3.8)
project(my_robot_pkg)

# Default to C++17
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# ── Find dependencies ──────────────────────────────────────────
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rclcpp_components REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(tf2_ros REQUIRED)
find_package(cv_bridge REQUIRED)
find_package(OpenCV REQUIRED)

# ── Custom messages / services / actions ───────────────────────
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/Detection.msg"
  "srv/GetPose.srv"
  "action/PickPlace.action"
  DEPENDENCIES geometry_msgs sensor_msgs
)

# ── Standalone executable node ─────────────────────────────────
add_executable(perception_node src/perception_node.cpp)
ament_target_dependencies(perception_node
  rclcpp sensor_msgs cv_bridge OpenCV tf2_ros
)
install(TARGETS perception_node
  DESTINATION lib/${PROJECT_NAME}
)

# ── Component (composable node) ────────────────────────────────
add_library(perception_component SHARED
  src/perception_component.cpp
)
ament_target_dependencies(perception_component
  rclcpp rclcpp_components sensor_msgs cv_bridge OpenCV
)
# Register as a composable node
rclcpp_components_register_node(perception_component
  PLUGIN "my_robot_pkg::PerceptionComponent"
  EXECUTABLE perception_component_node
)
install(TARGETS perception_component
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)

# ── Install Python nodes ───────────────────────────────────────
install(PROGRAMS
  scripts/planning_node.py
  DESTINATION lib/${PROJECT_NAME}
)

# ── Install launch, config, rviz, urdf ─────────────────────────
install(DIRECTORY
  launch config rviz urdf
  DESTINATION share/${PROJECT_NAME}
)

# ── Install headers ────────────────────────────────────────────
install(DIRECTORY include/
  DESTINATION include
)

# ── Tests ──────────────────────────────────────────────────────
if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  ament_lint_auto_find_test_dependencies()

  find_package(ament_cmake_pytest REQUIRED)
  ament_add_pytest_test(test_perception test/test_perception.py)

  find_package(launch_testing_ament_cmake REQUIRED)
  add_launch_test(test/test_integration.py)
endif()

ament_package()
```

### setup.py / setup.cfg — Pure Python Package

```python
# setup.py (for ament_python packages)
from setuptools import find_packages, setup

package_name = 'my_python_pkg'

setup(
    name=package_name,
    version='0.1.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        # Register with ament index
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        # Package manifest
        ('share/' + package_name, ['package.xml']),
        # Launch files
        ('share/' + package_name + '/launch',
            ['launch/robot.launch.py']),
        # Config files
        ('share/' + package_name + '/config',
            ['config/params.yaml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Dev Name',
    maintainer_email='dev@example.com',
    description='My Python robot package',
    license='Apache-2.0',
    entry_points={
        'console_scripts': [
            # format: 'executable_name = package.module:function'
            'perception_node = my_python_pkg.perception_node:main',
            'planner_node = my_python_pkg.planner_node:main',
        ],
    },
)
```

```cfg
# setup.cfg
[develop]
script_dir=$base/lib/my_python_pkg

[install]
install_scripts=$base/lib/my_python_pkg
```

### Custom Message, Service, and Action Definitions

```
# msg/Detection.msg
std_msgs/Header header
string class_name
float32 confidence
geometry_msgs/Pose pose
float32[4] bbox    # [x_min, y_min, x_max, y_max]
```

```
# srv/GetPose.srv
string object_name
---
bool success
geometry_msgs/PoseStamped pose
string error_message
```

```
# action/PickPlace.action
# Goal
geometry_msgs/Pose target_pose
string object_class
---
# Result
bool success
string error_message
---
# Feedback
float32 progress
string current_phase
```

### Workspace Overlays

```
Underlay (base ROS2)         /opt/ros/humble/
    ↑
Overlay 1 (shared libs)     ~/ros2_ws/install/
    ↑
Overlay 2 (your dev pkg)    ~/dev_ws/install/

Source order matters — LAST sourced overlay wins for duplicate packages.
```

```bash
# Correct source order
source /opt/ros/humble/setup.bash    # Base
source ~/ros2_ws/install/setup.bash  # Shared workspace
source ~/dev_ws/install/setup.bash   # Your development overlay

# NEVER source setup.bash from build/ — always use install/
```

### Build Troubleshooting

```bash
# "Package not found" during build
# → Missing dependency. Check package.xml and run:
rosdep install --from-paths src --ignore-src -y

# "Could not find a package configuration file provided by X"
# → CMake can't find the package. Did you source the underlay?
source /opt/ros/humble/setup.bash

# Build succeeds but node can't be found at runtime
# → Forgot to source the overlay, or entry_points misconfigured
source install/setup.bash
ros2 pkg list | grep my_pkg      # Should appear
ros2 pkg executables my_pkg      # List available executables

# Python changes not reflected after rebuild
# → Use --symlink-install, or clean and rebuild
colcon build --packages-select my_pkg --symlink-install

# "Multiple packages with the same name"
# → Duplicate package in workspace. Check with:
colcon list --packages-select my_pkg

# Build runs out of memory (large C++ packages)
colcon build --parallel-workers 2 --executor sequential

# Custom messages not found by Python nodes
# → Missing rosidl_default_runtime in package.xml exec_depend
# → Or forgot to source install/setup.bash after building msgs
```
