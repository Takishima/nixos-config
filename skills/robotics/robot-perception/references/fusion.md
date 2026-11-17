# Multi-Sensor Fusion

### Perception Fusion Architecture

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  RGB Camera  │    │ Depth Sensor │    │    LiDAR     │
│   30 Hz      │    │   30 Hz      │    │   10 Hz      │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Detection   │    │    Depth     │    │ Point Cloud  │
│  + Segment   │    │  Filtering   │    │  Processing  │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────┬───────┘───────────────────┘
                   ▼
          ┌────────────────┐
          │  Fusion Layer  │
          │  (association  │
          │   + tracking)  │
          └────────┬───────┘
                   ▼
          ┌────────────────┐
          │  World Model   │
          │  (tracked      │
          │   objects)     │
          └────────────────┘
```

### Camera + LiDAR Fusion

```python
class CameraLiDARFusion:
    """Project LiDAR points into camera image for cross-modal association.

    Two fusion strategies:
    1. Early fusion: Project LiDAR → camera, combine at data level
    2. Late fusion: Detect in each modality, associate results

    Early fusion is simpler and recommended when sensors are calibrated.
    """

    def __init__(self, K, T_lidar_to_camera, image_size):
        self.K = K
        self.T = T_lidar_to_camera  # 4x4 transform
        self.image_size = image_size  # (w, h)

    def project_lidar_to_image(self, lidar_points):
        """Project 3D LiDAR points to 2D image pixels.

        Returns:
            pixels: (N, 2) pixel coordinates
            depths: (N,) depth values
            valid_mask: (N,) bool — True if point projects into image
        """
        N = len(lidar_points)
        # Homogeneous coordinates
        pts_h = np.hstack([lidar_points[:, :3], np.ones((N, 1))])

        # Transform to camera frame
        pts_cam = (self.T @ pts_h.T).T

        # Points behind camera
        valid = pts_cam[:, 2] > 0
        depths = pts_cam[:, 2]

        # Project to pixels
        pixels = np.zeros((N, 2))
        pixels[:, 0] = self.K[0, 0] * pts_cam[:, 0] / pts_cam[:, 2] + self.K[0, 2]
        pixels[:, 1] = self.K[1, 1] * pts_cam[:, 1] / pts_cam[:, 2] + self.K[1, 2]

        # Check image bounds
        w, h = self.image_size
        valid &= (pixels[:, 0] >= 0) & (pixels[:, 0] < w)
        valid &= (pixels[:, 1] >= 0) & (pixels[:, 1] < h)

        return pixels, depths, valid

    def colorize_pointcloud(self, lidar_points, rgb_image):
        """Paint LiDAR points with RGB colors from camera image"""
        pixels, depths, valid = self.project_lidar_to_image(lidar_points)

        colors = np.zeros((len(lidar_points), 3), dtype=np.float32)
        valid_px = pixels[valid].astype(int)
        colors[valid] = rgb_image[valid_px[:, 1], valid_px[:, 0]] / 255.0

        return colors, valid

    def enrich_detections(self, detections_2d, lidar_points):
        """Add 3D information to 2D camera detections using LiDAR.

        For each 2D bounding box, find LiDAR points that project
        inside it, and compute the 3D centroid.
        """
        pixels, depths, valid = self.project_lidar_to_image(lidar_points)

        enriched = []
        for det in detections_2d:
            x1, y1, x2, y2 = det.bbox

            # Find LiDAR points inside this bounding box
            in_box = (valid &
                      (pixels[:, 0] >= x1) & (pixels[:, 0] <= x2) &
                      (pixels[:, 1] >= y1) & (pixels[:, 1] <= y2))

            if in_box.sum() > 3:
                # Use LiDAR points for 3D position (more accurate than depth camera)
                box_points = lidar_points[in_box]

                # Median is robust to outliers from other objects
                position_3d = np.median(box_points[:, :3], axis=0)
                det.position_3d = position_3d
                det.num_lidar_points = in_box.sum()
                det.has_3d = True
            else:
                det.has_3d = False

            enriched.append(det)

        return enriched
```

### Multi-Object Tracking

```python
class PerceptionTracker:
    """Track detected objects across frames for temporal consistency.

    Why tracking matters in robotics:
    - Detections flicker (present one frame, absent the next)
    - Robot needs consistent object IDs for manipulation
    - Velocity estimation requires temporal association
    - Occlusion handling prevents phantom disappearances
    """

    def __init__(self, max_age=5, min_hits=3, iou_threshold=0.3):
        self.max_age = max_age            # Frames before deleting lost track
        self.min_hits = min_hits          # Frames before confirming track
        self.iou_threshold = iou_threshold
        self.tracks = {}
        self.next_id = 0

    def update(self, detections) -> list:
        """Associate detections with existing tracks.

        Uses Hungarian algorithm for optimal assignment.
        """
        if not self.tracks:
            # First frame: create tracks for all detections
            for det in detections:
                self._create_track(det)
            return list(self.tracks.values())

        # Compute cost matrix (IoU for 2D, Euclidean for 3D)
        track_list = list(self.tracks.values())
        cost_matrix = self._compute_cost_matrix(track_list, detections)

        # Hungarian assignment
        from scipy.optimize import linear_sum_assignment
        row_idx, col_idx = linear_sum_assignment(cost_matrix)

        matched = set()
        for r, c in zip(row_idx, col_idx):
            if cost_matrix[r, c] < self.iou_threshold:
                track_list[r].update(detections[c])
                matched.add(c)

        # Create new tracks for unmatched detections
        for i, det in enumerate(detections):
            if i not in matched:
                self._create_track(det)

        # Age out old tracks
        stale = [tid for tid, t in self.tracks.items()
                 if t.age > self.max_age]
        for tid in stale:
            del self.tracks[tid]

        # Return confirmed tracks only
        return [t for t in self.tracks.values()
                if t.hits >= self.min_hits]

    def _create_track(self, detection):
        track = Track(
            track_id=self.next_id,
            detection=detection,
            hits=1, age=0)
        self.tracks[self.next_id] = track
        self.next_id += 1

    def _compute_cost_matrix(self, tracks, detections):
        n_tracks = len(tracks)
        n_dets = len(detections)
        cost = np.ones((n_tracks, n_dets))

        for i, track in enumerate(tracks):
            for j, det in enumerate(detections):
                if hasattr(det, 'position_3d') and det.position_3d is not None:
                    # 3D Euclidean distance (preferred)
                    dist = np.linalg.norm(
                        track.position_3d - det.position_3d)
                    cost[i, j] = dist
                else:
                    # 2D IoU
                    cost[i, j] = 1.0 - self._iou(track.bbox, det.bbox)

        return cost

    @staticmethod
    def _iou(box1, box2):
        x1 = max(box1[0], box2[0])
        y1 = max(box1[1], box2[1])
        x2 = min(box1[2], box2[2])
        y2 = min(box1[3], box2[3])
        inter = max(0, x2 - x1) * max(0, y2 - y1)
        area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
        area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
        return inter / (area1 + area2 - inter + 1e-6)
```
