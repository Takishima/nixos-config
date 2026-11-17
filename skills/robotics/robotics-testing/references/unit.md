# Unit Testing Patterns

### Testing ROS2 Nodes with pytest

```python
# test_perception_node.py
import pytest
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image
from my_pkg.perception_node import PerceptionNode
import numpy as np

@pytest.fixture(scope='module')
def ros_context():
    """Initialize ROS2 context once per test module"""
    rclpy.init()
    yield
    rclpy.shutdown()

@pytest.fixture
def perception_node(ros_context):
    """Create a fresh perception node for each test"""
    node = PerceptionNode()
    yield node
    node.destroy_node()

@pytest.fixture
def test_image():
    """Generate a synthetic test image"""
    msg = Image()
    msg.height = 256
    msg.width = 256
    msg.encoding = 'rgb8'
    msg.step = 256 * 3
    msg.data = np.random.randint(0, 255, (256, 256, 3),
                                  dtype=np.uint8).tobytes()
    return msg

class TestPerceptionNode:

    def test_initialization(self, perception_node):
        """Node should initialize with correct default parameters"""
        assert perception_node.get_parameter('confidence_threshold').value == 0.7
        assert perception_node.get_parameter('rate_hz').value == 30.0

    def test_parameter_validation(self, perception_node):
        """Node should reject invalid parameter values"""
        from rcl_interfaces.msg import SetParametersResult
        result = perception_node.set_parameters([
            rclpy.parameter.Parameter('confidence_threshold',
                                       value=-0.5)  # Invalid!
        ])
        assert not result[0].successful

    def test_image_callback_publishes_detections(self, perception_node, test_image):
        """Processing an image should produce detection output"""
        received = []

        # Create a test subscriber
        sub_node = Node('test_subscriber')
        sub_node.create_subscription(
            DetectionArray, '/perception/detections',
            lambda msg: received.append(msg), 10)

        # Simulate image callback
        perception_node.image_callback(test_image)

        # Spin briefly to allow message propagation
        rclpy.spin_once(sub_node, timeout_sec=1.0)
        rclpy.spin_once(perception_node, timeout_sec=1.0)

        # Verify
        assert len(received) > 0
        sub_node.destroy_node()

    def test_empty_image_handling(self, perception_node):
        """Node should handle empty/corrupted images gracefully"""
        empty_msg = Image()  # No data
        # Should not crash
        perception_node.image_callback(empty_msg)
```

### Testing Pure Functions (No ROS Dependency)

```python
# test_kinematics.py
import pytest
import numpy as np
from my_pkg.kinematics import (
    forward_kinematics, inverse_kinematics,
    quaternion_multiply, transform_point
)

class TestForwardKinematics:

    @pytest.mark.parametrize("joint_angles,expected_pos", [
        # Home position
        (np.zeros(7), np.array([0.088, 0.0, 1.033])),
        # Known calibrated pose
        (np.array([0, -0.785, 0, -2.356, 0, 1.571, 0.785]),
         np.array([0.307, 0.0, 0.59])),
    ])
    def test_known_poses(self, joint_angles, expected_pos):
        """FK should match known calibrated positions"""
        result = forward_kinematics(joint_angles)
        np.testing.assert_allclose(result[:3], expected_pos, atol=0.01)

    def test_fk_ik_roundtrip(self):
        """FK(IK(pose)) should return the original pose"""
        original_pose = np.array([0.4, 0.1, 0.5, 1.0, 0.0, 0.0, 0.0])
        joint_angles = inverse_kinematics(original_pose)
        recovered_pose = forward_kinematics(joint_angles)
        np.testing.assert_allclose(recovered_pose, original_pose, atol=1e-4)

    def test_joint_limits_respected(self):
        """IK should not return angles outside joint limits"""
        target = np.array([0.5, 0.2, 0.3, 1.0, 0.0, 0.0, 0.0])
        joints = inverse_kinematics(target)
        for i, (lo, hi) in enumerate(JOINT_LIMITS):
            assert lo <= joints[i] <= hi, \
                f"Joint {i}: {joints[i]} outside [{lo}, {hi}]"


class TestQuaternionMath:

    def test_identity_multiply(self):
        """q * identity = q"""
        q = np.array([0.5, 0.5, 0.5, 0.5])
        identity = np.array([1.0, 0.0, 0.0, 0.0])
        result = quaternion_multiply(q, identity)
        np.testing.assert_allclose(result, q, atol=1e-10)

    def test_inverse_multiply(self):
        """q * q_inv = identity"""
        q = np.array([0.5, 0.5, 0.5, 0.5])
        q_inv = np.array([0.5, -0.5, -0.5, -0.5])
        result = quaternion_multiply(q, q_inv)
        np.testing.assert_allclose(result, [1, 0, 0, 0], atol=1e-10)

    @pytest.mark.parametrize("q", [
        np.random.randn(4) for _ in range(20)  # Random quaternions
    ])
    def test_unit_quaternion_preserved(self, q):
        """Multiplication of unit quaternions should produce unit quaternion"""
        q = q / np.linalg.norm(q)  # Normalize
        q2 = np.array([0.707, 0.707, 0, 0])  # 90° rotation
        result = quaternion_multiply(q, q2)
        assert abs(np.linalg.norm(result) - 1.0) < 1e-10
```

### Property-Based Testing with Hypothesis

```python
from hypothesis import given, strategies as st, settings
import hypothesis.extra.numpy as hnp

class TestTrajectoryInterpolation:

    @given(
        start=hnp.arrays(np.float64, (7,),
            elements=st.floats(min_value=-3.14, max_value=3.14)),
        end=hnp.arrays(np.float64, (7,),
            elements=st.floats(min_value=-3.14, max_value=3.14)),
        num_steps=st.integers(min_value=2, max_value=1000),
    )
    @settings(max_examples=200)
    def test_interpolation_properties(self, start, end, num_steps):
        """Trajectory interpolation should satisfy mathematical properties"""
        traj = linear_interpolate(start, end, num_steps)

        # Property 1: Correct number of steps
        assert len(traj) == num_steps

        # Property 2: Starts at start, ends at end
        np.testing.assert_allclose(traj[0], start, atol=1e-10)
        np.testing.assert_allclose(traj[-1], end, atol=1e-10)

        # Property 3: Monotonic progress (each step closer to goal)
        for i in range(1, len(traj)):
            dist_prev = np.linalg.norm(traj[i-1] - end)
            dist_curr = np.linalg.norm(traj[i] - end)
            assert dist_curr <= dist_prev + 1e-10

        # Property 4: No jumps exceed max step size
        diffs = np.diff(traj, axis=0)
        max_step = np.max(np.abs(diffs))
        expected_max = np.max(np.abs(end - start)) / (num_steps - 1)
        assert max_step <= expected_max + 1e-10

    @given(
        points=hnp.arrays(np.float64, (3,),
            elements=st.floats(min_value=-10, max_value=10, allow_nan=False)),
    )
    def test_transform_roundtrip(self, points):
        """Transform followed by inverse transform = identity"""
        T = random_transform_matrix()
        T_inv = np.linalg.inv(T)
        transformed = transform_point(T, points)
        recovered = transform_point(T_inv, transformed)
        np.testing.assert_allclose(recovered, points, atol=1e-8)
```
