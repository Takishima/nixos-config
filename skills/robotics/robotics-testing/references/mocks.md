# Mock Hardware Patterns

```python
class MockCamera:
    """Mock camera for testing without hardware"""

    def __init__(self, image_dir=None, resolution=(640, 480)):
        self.resolution = resolution
        self.frame_count = 0

        if image_dir:
            # Use pre-recorded test images
            self.images = self._load_test_images(image_dir)
        else:
            # Generate synthetic images
            self.images = None

    def get_frame(self):
        self.frame_count += 1
        if self.images:
            idx = self.frame_count % len(self.images)
            return self.images[idx]
        else:
            return self._generate_synthetic_frame()

    def _generate_synthetic_frame(self):
        """Generate a deterministic test frame with known objects"""
        img = np.zeros((*self.resolution[::-1], 3), dtype=np.uint8)
        # Draw a red rectangle (simulated object)
        img[100:200, 150:250] = [255, 0, 0]
        return img


class MockJointStatePublisher:
    """Publish deterministic joint states for testing"""

    def __init__(self, node, trajectory=None):
        self.pub = node.create_publisher(
            JointState, '/joint_states', 10)
        self.step = 0

        if trajectory is not None:
            self.trajectory = trajectory
        else:
            # Sinusoidal motion for testing
            t = np.linspace(0, 2*np.pi, 100)
            self.trajectory = np.column_stack([
                0.1 * np.sin(t + i * 0.5) for i in range(7)
            ])

    def publish_next(self):
        msg = JointState()
        msg.header.stamp = self.node.get_clock().now().to_msg()
        msg.name = [f'joint_{i}' for i in range(7)]
        idx = self.step % len(self.trajectory)
        msg.position = self.trajectory[idx].tolist()
        self.pub.publish(msg)
        self.step += 1
```
