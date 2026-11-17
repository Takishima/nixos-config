# Launch File Composition and Layering

### Launch Layer Architecture

Organize launch files into layers that mirror the systemd service architecture. Each layer is an independent launch file that can be tested in isolation.

```
bringup.launch.py  (top-level: composes all layers)
├── hardware.launch.py     (udev checks, device readiness)
├── drivers.launch.py      (camera, LiDAR, IMU, motor drivers)
│   ├── camera.launch.py
│   ├── lidar.launch.py
│   └── motors.launch.py
├── perception.launch.py   (SLAM, detection, fusion)
│   ├── slam.launch.py
│   └── detection.launch.py
└── application.launch.py  (navigation, planning, HRI)
    ├── navigation.launch.py
    └── mission.launch.py
```

### Hardware Layer Launch

```python
# my_robot_bringup/launch/hardware.launch.py
from launch import LaunchDescription
from launch.actions import LogInfo, ExecuteProcess, TimerAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, EnvironmentVariable

def generate_launch_description():
    # Declare arguments for hardware configuration
    robot_name = LaunchConfiguration('robot_name',
        default=EnvironmentVariable('ROBOT_NAME', default_value='default_robot'))

    # Check that critical devices are present
    check_camera = ExecuteProcess(
        cmd=['test', '-e', '/dev/robot/camera_front'],
        name='check_camera_front',
        output='screen',
    )

    check_lidar = ExecuteProcess(
        cmd=['test', '-e', '/dev/robot/lidar'],
        name='check_lidar',
        output='screen',
    )

    check_imu = ExecuteProcess(
        cmd=['test', '-e', '/dev/robot/imu'],
        name='check_imu',
        output='screen',
    )

    log_ready = TimerAction(
        period=2.0,
        actions=[LogInfo(msg='Hardware checks passed, devices ready')],
    )

    return LaunchDescription([
        check_camera,
        check_lidar,
        check_imu,
        log_ready,
    ])
```

### Driver Layer Launch

```python
# my_robot_bringup/launch/drivers.launch.py
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, GroupAction
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node, SetRemap
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    use_sim = LaunchConfiguration('use_sim', default='false')
    camera_config = LaunchConfiguration('camera_config', default='default')

    # Camera driver
    camera_node = Node(
        package='usb_cam',
        executable='usb_cam_node_exe',
        name='camera_front',
        parameters=[PathJoinSubstitution([
            FindPackageShare('my_robot_bringup'), 'config', 'camera_front.yaml'
        ])],
        remappings=[('/image_raw', '/camera/front/image_raw')],
    )

    # LiDAR driver
    lidar_node = Node(
        package='sllidar_ros2',
        executable='sllidar_node',
        name='lidar',
        parameters=[{
            'serial_port': '/dev/robot/lidar',
            'serial_baudrate': 460800,
            'frame_id': 'lidar_link',
            'angle_compensate': True,
        }],
    )

    # IMU driver
    imu_node = Node(
        package='imu_driver',
        executable='imu_node',
        name='imu',
        parameters=[{
            'port': '/dev/robot/imu',
            'frame_id': 'imu_link',
            'publish_rate': 100.0,
        }],
    )

    # Motor controller driver
    motor_node = Node(
        package='motor_driver',
        executable='motor_controller_node',
        name='motor_controller',
        parameters=[PathJoinSubstitution([
            FindPackageShare('my_robot_bringup'), 'config', 'motors.yaml'
        ])],
    )

    return LaunchDescription([
        DeclareLaunchArgument('use_sim', default_value='false'),
        DeclareLaunchArgument('camera_config', default_value='default'),
        camera_node,
        lidar_node,
        imu_node,
        motor_node,
    ])
```

### Perception Layer Launch

```python
# my_robot_bringup/launch/perception.launch.py
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, GroupAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node, ComposableNodeContainer, LoadComposableNode
from launch_ros.descriptions import ComposableNode
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    enable_slam = LaunchConfiguration('enable_slam', default='true')
    enable_detection = LaunchConfiguration('enable_detection', default='true')

    # Use a composable node container for zero-copy perception pipeline
    perception_container = ComposableNodeContainer(
        name='perception_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container_mt',
        composable_node_descriptions=[
            ComposableNode(
                package='image_proc',
                plugin='image_proc::RectifyNode',
                name='rectify',
                remappings=[('image', '/camera/front/image_raw')],
            ),
            ComposableNode(
                package='my_detection',
                plugin='my_detection::DetectorNode',
                name='detector',
                parameters=[PathJoinSubstitution([
                    FindPackageShare('my_robot_bringup'), 'config', 'detector.yaml'
                ])],
            ),
        ],
        condition=IfCondition(enable_detection),
    )

    # SLAM node
    slam_node = Node(
        package='slam_toolbox',
        executable='async_slam_toolbox_node',
        name='slam',
        parameters=[PathJoinSubstitution([
            FindPackageShare('my_robot_bringup'), 'config', 'slam.yaml'
        ])],
        condition=IfCondition(enable_slam),
    )

    return LaunchDescription([
        DeclareLaunchArgument('enable_slam', default_value='true'),
        DeclareLaunchArgument('enable_detection', default_value='true'),
        perception_container,
        slam_node,
    ])
```

### Application Layer Launch

```python
# my_robot_bringup/launch/application.launch.py
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    nav_params = LaunchConfiguration('nav_params', default=PathJoinSubstitution([
        FindPackageShare('my_robot_bringup'), 'config', 'nav2_params.yaml'
    ]))

    # Include Nav2 bringup
    nav2_bringup = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(PathJoinSubstitution([
            FindPackageShare('nav2_bringup'), 'launch', 'bringup_launch.py'
        ])),
        launch_arguments={
            'params_file': nav_params,
            'use_sim_time': LaunchConfiguration('use_sim', default='false'),
        }.items(),
    )

    # Mission planner
    mission_node = Node(
        package='my_mission',
        executable='mission_planner',
        name='mission_planner',
        parameters=[PathJoinSubstitution([
            FindPackageShare('my_robot_bringup'), 'config', 'mission.yaml'
        ])],
    )

    return LaunchDescription([
        DeclareLaunchArgument('nav_params', default_value=''),
        DeclareLaunchArgument('use_sim', default_value='false'),
        nav2_bringup,
        mission_node,
    ])
```

### Top-Level Bringup Launch

This launch file composes all layers into a single entry point, with conditional arguments for simulation vs. real hardware and robot variant selection.

```python
# my_robot_bringup/launch/bringup.launch.py
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument, IncludeLaunchDescription,
    GroupAction, LogInfo, TimerAction,
)
from launch.conditions import IfCondition, UnlessCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import (
    LaunchConfiguration, PathJoinSubstitution, PythonExpression,
)
from launch_ros.actions import PushRosNamespace, SetParameter
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    pkg_share = FindPackageShare('my_robot_bringup')
    use_sim = LaunchConfiguration('use_sim')
    robot_variant = LaunchConfiguration('robot_variant')
    enable_perception = LaunchConfiguration('enable_perception')
    enable_navigation = LaunchConfiguration('enable_navigation')

    # Hardware layer (skip in simulation)
    hardware_launch = GroupAction(
        actions=[
            LogInfo(msg='Starting hardware layer...'),
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource(
                    PathJoinSubstitution([pkg_share, 'launch', 'hardware.launch.py'])
                ),
            ),
        ],
        condition=UnlessCondition(use_sim),
    )

    # Driver layer
    drivers_launch = GroupAction(
        actions=[
            LogInfo(msg='Starting driver layer...'),
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource(
                    PathJoinSubstitution([pkg_share, 'launch', 'drivers.launch.py'])
                ),
                launch_arguments={'use_sim': use_sim}.items(),
            ),
        ],
    )

    # Perception layer (conditional)
    perception_launch = GroupAction(
        actions=[
            LogInfo(msg='Starting perception layer...'),
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource(
                    PathJoinSubstitution([pkg_share, 'launch', 'perception.launch.py'])
                ),
            ),
        ],
        condition=IfCondition(enable_perception),
    )

    # Application layer (conditional)
    application_launch = GroupAction(
        actions=[
            LogInfo(msg='Starting application layer...'),
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource(
                    PathJoinSubstitution([pkg_share, 'launch', 'application.launch.py'])
                ),
                launch_arguments={'use_sim': use_sim}.items(),
            ),
        ],
        condition=IfCondition(enable_navigation),
    )

    return LaunchDescription([
        DeclareLaunchArgument('use_sim', default_value='false',
            description='Use simulation instead of real hardware'),
        DeclareLaunchArgument('robot_variant', default_value='standard',
            description='Robot variant: standard, heavy_payload, outdoor'),
        DeclareLaunchArgument('enable_perception', default_value='true',
            description='Enable perception stack'),
        DeclareLaunchArgument('enable_navigation', default_value='true',
            description='Enable navigation and application stack'),

        # Set use_sim_time globally
        SetParameter(name='use_sim_time', value=use_sim),

        LogInfo(msg=['Bringing up robot variant: ', robot_variant]),

        hardware_launch,
        drivers_launch,
        perception_launch,
        application_launch,
    ])
```

### Conditional Loading (Sim vs Real, Robot Variants)

Use `IfCondition`, `UnlessCondition`, and `PythonExpression` to swap configurations based on runtime arguments.

```python
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import PythonExpression, LaunchConfiguration

robot_variant = LaunchConfiguration('robot_variant')

# Load a variant-specific config file
variant_config = PathJoinSubstitution([
    FindPackageShare('my_robot_bringup'), 'config', 'variants',
    PythonExpression(["'", robot_variant, "' + '.yaml'"]),
])

# Conditional node: only load the arm driver for heavy_payload variant
arm_driver = Node(
    package='arm_driver',
    executable='arm_controller_node',
    name='arm_controller',
    condition=IfCondition(
        PythonExpression(["'", robot_variant, "' == 'heavy_payload'"])
    ),
)
```
