# Pattern 4: Perception Pipeline

```
Raw Sensors → Preprocessing → Detection/Estimation → Fusion → World Model
```

### Sensor Fusion Architecture

```python
class SensorFusion:
    """Multi-sensor fusion using a central world model"""

    def __init__(self):
        self.world_model = WorldModel()
        self.filters = {
            'pose': ExtendedKalmanFilter(state_dim=6),
            'objects': MultiObjectTracker(),
        }

    def update_from_camera(self, detections, timestamp):
        """Camera provides object detections with high latency"""
        for det in detections:
            self.filters['objects'].update(
                det, sensor='camera',
                uncertainty=det.confidence,
                timestamp=timestamp
            )

    def update_from_lidar(self, points, timestamp):
        """LiDAR provides precise geometry with lower latency"""
        clusters = self.segment_points(points)
        for cluster in clusters:
            self.filters['objects'].update(
                cluster, sensor='lidar',
                uncertainty=0.02,  # 2cm typical LiDAR accuracy
                timestamp=timestamp
            )

    def update_from_imu(self, imu_data, timestamp):
        """IMU provides high-frequency attitude estimates"""
        self.filters['pose'].predict(imu_data, dt=timestamp - self.last_imu_t)
        self.last_imu_t = timestamp

    def get_world_state(self):
        """Query the fused world model"""
        return WorldState(
            robot_pose=self.filters['pose'].state,
            objects=self.filters['objects'].get_tracked_objects(),
            confidence=self.filters['objects'].get_confidence_map()
        )
```

### The Perception-Action Loop Timing

```
Camera (30Hz)  ─┐
LiDAR (10Hz)   ─┼──→ Fusion (50Hz) ──→ Planner (10Hz) ──→ Controller (100Hz+)
IMU (200Hz)    ─┘

RULE: Controller frequency > Planner frequency > Sensor frequency
      This ensures smooth execution despite variable perception latency.
```
