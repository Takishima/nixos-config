# Integration Testing

### ROS2 Launch Testing

```python
# test_integration.py
import pytest
import launch_testing
from launch import LaunchDescription
from launch_ros.actions import Node
import rclpy
import unittest

@pytest.mark.launch_test
def generate_test_description():
    """Launch the nodes we want to test"""
    perception_node = Node(
        package='my_pkg', executable='perception_node',
        parameters=[{'use_sim_time': True}],
    )
    planner_node = Node(
        package='my_pkg', executable='planner_node',
        parameters=[{'use_sim_time': True}],
    )

    return LaunchDescription([
        perception_node,
        planner_node,
        launch_testing.actions.ReadyToTest(),
    ])


class TestPerceptionPlannerIntegration(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        rclpy.init()
        cls.node = rclpy.create_node('integration_test')

    @classmethod
    def tearDownClass(cls):
        cls.node.destroy_node()
        rclpy.shutdown()

    def test_perception_publishes_to_planner(self):
        """Perception detections should reach the planner"""
        # Publish a test image
        pub = self.node.create_publisher(Image, '/camera/image_raw', 10)
        test_img = create_test_image_with_object()
        pub.publish(test_img)

        # Wait for planner output
        received = []
        sub = self.node.create_subscription(
            Path, '/planner/path',
            lambda msg: received.append(msg), 10)

        end_time = self.node.get_clock().now() + rclpy.duration.Duration(seconds=5)
        while self.node.get_clock().now() < end_time and not received:
            rclpy.spin_once(self.node, timeout_sec=0.1)

        self.assertGreater(len(received), 0, "Planner should produce a path")
        self.assertGreater(len(received[0].poses), 0, "Path should have poses")
```
