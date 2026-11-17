# Core Architecture

### 1. Node Design Patterns

**Basic Node (rclpy)**:

```python
#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from std_msgs.msg import String

class PerceptionNode(Node):
    def __init__(self):
        super().__init__('perception_node')

        # 1. Declare parameters with types and descriptions
        self.declare_parameter('rate_hz', 30.0,
            descriptor=ParameterDescriptor(
                description='Processing rate in Hz',
                floating_point_range=[FloatingPointRange(
                    from_value=1.0, to_value=120.0, step=0.0
                )]
            ))
        self.declare_parameter('confidence_threshold', 0.7)
        self.declare_parameter('frame_id', 'camera_link')

        # 2. Read parameters
        rate_hz = self.get_parameter('rate_hz').value
        self.threshold = self.get_parameter('confidence_threshold').value
        self.frame_id = self.get_parameter('frame_id').value

        # 3. Set up QoS profiles
        sensor_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            history=HistoryPolicy.KEEP_LAST,
            depth=1
        )
        reliable_qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10
        )

        # 4. Publishers first, then subscribers
        self.det_pub = self.create_publisher(
            DetectionArray, 'detections', reliable_qos)

        self.image_sub = self.create_subscription(
            Image, 'camera/image_raw', self.image_callback, sensor_qos)

        # 5. Timers for periodic work
        self.timer = self.create_timer(1.0 / rate_hz, self.timer_callback)

        # 6. Parameter change callback
        self.add_on_set_parameters_callback(self.param_callback)

        self.get_logger().info(
            f'Perception node started at {rate_hz}Hz, '
            f'threshold={self.threshold}')

    def param_callback(self, params):
        """Handle runtime parameter changes (replaces dynamic_reconfigure)"""
        for param in params:
            if param.name == 'confidence_threshold':
                self.threshold = param.value
                self.get_logger().info(f'Threshold updated to {param.value}')
        return SetParametersResult(successful=True)

    def image_callback(self, msg):
        # Process incoming images
        pass

    def timer_callback(self):
        # Periodic work
        pass

def main(args=None):
    rclpy.init(args=args)
    node = PerceptionNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
```

**Basic Node (rclcpp)**:

```cpp
#include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/image.hpp>
#include <vision_msgs/msg/detection2_d.hpp>
#include <memory>

class PerceptionNode : public rclcpp::Node {
public:
    PerceptionNode() : Node("perception_node") {
        // Declare and get parameters
        this->declare_parameter("rate_hz", 30.0);
        this->declare_parameter("confidence_threshold", 0.7);
        double rate_hz = this->get_parameter("rate_hz").as_double();

        // QoS
        auto sensor_qos = rclcpp::SensorDataQoS();
        auto reliable_qos = rclcpp::QoS(10).reliable();

        // Publishers and subscribers
        det_pub_ = this->create_publisher<vision_msgs::msg::Detection2D>("detections", reliable_qos);
        image_sub_ = this->create_subscription<sensor_msgs::msg::Image>(
            "camera/image_raw", sensor_qos, [this](const std::shared_ptr<const sensor_msgs::msg::Image>& msg){
                this->image_callback(msg);
            });

        timer_ = this->create_wall_timer(
            std::chrono::milliseconds(static_cast<int>(1000.0 / rate_hz)),
            [this](){ this->timer_callback(); });

        RCLCPP_INFO(this->get_logger(), "Perception node started at %.1fHz", rate_hz);
    }

private:
    void image_callback(const std::shared_ptr<const sensor_msgs::msg::Image>& msg) {
        // Use shared_ptr for zero-copy potential
    }
    void timer_callback() {}

    rclcpp::Publisher<vision_msgs::msg::Detection2D>::SharedPtr det_pub_;
    rclcpp::Subscription<sensor_msgs::msg::Image>::SharedPtr image_sub_;
    rclcpp::TimerBase::SharedPtr timer_;
};

int main(int argc, char** argv) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<PerceptionNode>());
    rclcpp::shutdown();
    return 0;
}
```

### 2. Lifecycle (Managed) Nodes

Use lifecycle nodes for production systems where you need deterministic startup, shutdown, and error recovery. This is one of ROS2's most important features over ROS1.

**State Machine**: `Unconfigured → Inactive → Active → Finalized`

```python
from rclpy.lifecycle import Node as LifecycleNode, TransitionCallbackReturn

class ManagedPerception(LifecycleNode):
    def __init__(self):
        super().__init__('managed_perception')
        self.get_logger().info('Node created (unconfigured)')

    def on_configure(self, state) -> TransitionCallbackReturn:
        """Load params, allocate memory, set up pubs/subs (but don't activate)"""
        self.declare_parameter('model_path', '')
        model_path = self.get_parameter('model_path').value

        try:
            self.model = load_model(model_path)
            self.det_pub = self.create_lifecycle_publisher(
                DetectionArray, 'detections', 10)
            self.get_logger().info(f'Configured with model: {model_path}')
            return TransitionCallbackReturn.SUCCESS
        except Exception as e:
            self.get_logger().error(f'Configuration failed: {e}')
            return TransitionCallbackReturn.FAILURE

    def on_activate(self, state) -> TransitionCallbackReturn:
        """Start processing — subscriptions go live here"""
        self.image_sub = self.create_subscription(
            Image, 'camera/image_raw', self.image_callback, 1)
        self.get_logger().info('Activated — processing images')
        return TransitionCallbackReturn.SUCCESS

    def on_deactivate(self, state) -> TransitionCallbackReturn:
        """Pause processing — safe to reconfigure after this"""
        self.destroy_subscription(self.image_sub)
        self.get_logger().info('Deactivated — stopped processing')
        return TransitionCallbackReturn.SUCCESS

    def on_cleanup(self, state) -> TransitionCallbackReturn:
        """Release resources, return to unconfigured"""
        del self.model
        self.get_logger().info('Cleaned up')
        return TransitionCallbackReturn.SUCCESS

    def on_shutdown(self, state) -> TransitionCallbackReturn:
        """Final cleanup before destruction"""
        self.get_logger().info('Shutting down')
        return TransitionCallbackReturn.SUCCESS

    def on_error(self, state) -> TransitionCallbackReturn:
        """Handle errors — try to recover or fail gracefully"""
        self.get_logger().error(f'Error in state {state.label}')
        return TransitionCallbackReturn.SUCCESS  # Transition to unconfigured
```

**Orchestrating Lifecycle Nodes** with a launch file:

```python
from launch import LaunchDescription
from launch_ros.actions import LifecycleNode
from launch_ros.event_handlers import OnStateTransition
from launch.actions import EmitEvent, RegisterEventHandler
from launch_ros.events.lifecycle import ChangeState
from lifecycle_msgs.msg import Transition

def generate_launch_description():
    perception = LifecycleNode(
        package='my_pkg', executable='managed_perception',
        name='perception', output='screen',
        parameters=[{'model_path': '/models/yolo.pt'}]
    )

    # Auto-configure on startup
    configure_event = EmitEvent(event=ChangeState(
        lifecycle_node_matcher=lambda node: node == perception,
        transition_id=Transition.TRANSITION_CONFIGURE
    ))

    # Auto-activate after successful configure
    activate_handler = RegisterEventHandler(OnStateTransition(
        target_lifecycle_node=perception,
        goal_state='inactive',
        entities=[EmitEvent(event=ChangeState(
            lifecycle_node_matcher=lambda node: node == perception,
            transition_id=Transition.TRANSITION_ACTIVATE
        ))]
    ))

    return LaunchDescription([
        perception,
        configure_event,
        activate_handler,
    ])
```

### 3. QoS (Quality of Service) — The #1 Source of ROS2 Bugs

QoS mismatches are the most common reason topics silently fail to connect.

**QoS Compatibility Matrix**:

```
Publisher     Subscriber    Compatible?
RELIABLE      RELIABLE      ✅ Yes
RELIABLE      BEST_EFFORT   ✅ Yes
BEST_EFFORT   BEST_EFFORT   ✅ Yes
BEST_EFFORT   RELIABLE      ❌ NO — SILENT FAILURE
```

**Recommended QoS Profiles by Use Case**:

```python
from rclpy.qos import (
    QoSProfile, QoSReliabilityPolicy, QoSHistoryPolicy,
    QoSDurabilityPolicy, QoSPresetProfiles
)

# Sensor data (cameras, lidars) — tolerate drops, want latest
SENSOR_QOS = QoSProfile(
    reliability=QoSReliabilityPolicy.BEST_EFFORT,
    history=QoSHistoryPolicy.KEEP_LAST,
    depth=1,
    durability=QoSDurabilityPolicy.VOLATILE
)

# Commands (velocity, joint) — never miss, small buffer
COMMAND_QOS = QoSProfile(
    reliability=QoSReliabilityPolicy.RELIABLE,
    history=QoSHistoryPolicy.KEEP_LAST,
    depth=10,
    durability=QoSDurabilityPolicy.VOLATILE
)

# Map / static data — reliable, and late joiners get it
MAP_QOS = QoSProfile(
    reliability=QoSReliabilityPolicy.RELIABLE,
    history=QoSHistoryPolicy.KEEP_LAST,
    depth=1,
    durability=QoSDurabilityPolicy.TRANSIENT_LOCAL  # Replaces ROS1 latch
)

# Default parameter/state — reliable with some history
STATE_QOS = QoSProfile(
    reliability=QoSReliabilityPolicy.RELIABLE,
    history=QoSHistoryPolicy.KEEP_LAST,
    depth=10
)
```

**Debugging QoS Issues**:

```bash
# Check QoS info for a topic
ros2 topic info /camera/image_raw -v
# Look for "Reliability" and "Durability" fields

# Check for incompatible QoS events
ros2 run rqt_topic rqt_topic  # Shows sub counts and QoS

# If 0 subscribers despite nodes running: QoS MISMATCH
```

### 4. Launch Files (Python-Based)

ROS2 launch files are Python, enabling powerful conditional logic:

```python
import os
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument, IncludeLaunchDescription,
    GroupAction, OpaqueFunction, TimerAction
)
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import (
    LaunchConfiguration, PathJoinSubstitution,
    PythonExpression
)
from launch_ros.actions import Node, ComposableNodeContainer, LoadComposableNode
from launch_ros.descriptions import ComposableNode
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():

    # Arguments
    robot_name_arg = DeclareLaunchArgument('robot_name', default_value='ur5')
    sim_arg = DeclareLaunchArgument('sim', default_value='false')
    use_composition_arg = DeclareLaunchArgument('use_composition', default_value='true')

    robot_name = LaunchConfiguration('robot_name')
    sim = LaunchConfiguration('sim')

    # Load YAML params
    config_file = PathJoinSubstitution([
        FindPackageShare('my_pkg'), 'config', 'robot_params.yaml'
    ])

    # Standard node
    perception_node = Node(
        package='my_pkg',
        executable='perception_node',
        name='perception',
        namespace=robot_name,
        parameters=[config_file, {'use_sim_time': sim}],
        remappings=[
            ('camera/image_raw', 'realsense/color/image_raw'),
            ('detections', 'perception/detections'),
        ],
        output='screen',
        condition=UnlessCondition(LaunchConfiguration('use_composition')),
    )

    # Composable nodes (zero-copy, same process)
    composable_container = ComposableNodeContainer(
        name='perception_container',
        namespace=robot_name,
        package='rclcpp_components',
        executable='component_container_mt',  # Multi-threaded
        composable_node_descriptions=[
            ComposableNode(
                package='my_pkg',
                plugin='my_pkg::PerceptionComponent',
                name='perception',
                parameters=[config_file],
                remappings=[
                    ('camera/image_raw', 'realsense/color/image_raw'),
                ],
            ),
            ComposableNode(
                package='my_pkg',
                plugin='my_pkg::TrackerComponent',
                name='tracker',
            ),
        ],
        condition=IfCondition(LaunchConfiguration('use_composition')),
    )

    # Delayed start for nodes that need others to initialize first
    delayed_planner = TimerAction(
        period=3.0,
        actions=[
            Node(package='my_pkg', executable='planner_node', name='planner')
        ]
    )

    return LaunchDescription([
        robot_name_arg, sim_arg, use_composition_arg,
        perception_node,
        composable_container,
        delayed_planner,
    ])
```

### 5. Components (ROS2's Answer to Nodelets)

```cpp
#include <rclcpp/rclcpp.hpp>
#include <rclcpp_components/register_node_macro.hpp>
#include <sensor_msgs/msg/image.hpp>

namespace my_pkg {

class PerceptionComponent : public rclcpp::Node {
public:
    explicit PerceptionComponent(const rclcpp::NodeOptions& options)
        : Node("perception", options)
    {
        // Use intra-process communication for zero-copy
        auto sub_options = rclcpp::SubscriptionOptions();
        sub_options.use_intra_process_comm =
            rclcpp::IntraProcessSetting::Enable;

        sub_ = this->create_subscription<sensor_msgs::msg::Image>(
            "camera/image_raw",
            rclcpp::SensorDataQoS(),
            [this](sensor_msgs::msg::Image::UniquePtr msg) {
                this->callback(std::move(msg));
            },
            sub_options);
    }

private:
    void callback(sensor_msgs::msg::Image::UniquePtr msg) {
        // UniquePtr = zero-copy when:
        //   - publisher also uses UniquePtr
        //   - both subscriber and publisher use intra-process
        //   - this is the only subscriber
        // msg is moved, not copied
    }

    rclcpp::Subscription<sensor_msgs::msg::Image>::SharedPtr sub_;
};

}  // namespace my_pkg

RCLCPP_COMPONENTS_REGISTER_NODE(my_pkg::PerceptionComponent)
```

### 6. Actions (ROS2 Style)

```python
from rclpy.action import ActionServer, CancelResponse, GoalResponse
from my_interfaces.action import PickPlace

class PickPlaceServer(Node):
    def __init__(self):
        super().__init__('pick_place_server')
        self._action_server = ActionServer(
            self, PickPlace, 'pick_place',
            execute_callback=self.execute_cb,
            goal_callback=self.goal_cb,
            cancel_callback=self.cancel_cb,
        )

    def goal_cb(self, goal_request):
        """Decide whether to accept or reject the goal"""
        self.get_logger().info(f'Received goal: {goal_request.target_pose}')
        return GoalResponse.ACCEPT

    def cancel_cb(self, goal_handle):
        """Decide whether to accept cancel requests"""
        self.get_logger().info('Cancel requested')
        return CancelResponse.ACCEPT

    async def execute_cb(self, goal_handle):
        """Execute the action (runs in an executor thread)"""
        feedback_msg = PickPlace.Feedback()

        for i, step in enumerate(self.plan(goal_handle.request)):
            # Check cancellation
            if goal_handle.is_cancel_requested:
                goal_handle.canceled()
                return PickPlace.Result(success=False)

            self.execute_step(step)
            feedback_msg.progress = float(i) / len(self.steps)
            goal_handle.publish_feedback(feedback_msg)

        goal_handle.succeed()
        return PickPlace.Result(success=True)
```
