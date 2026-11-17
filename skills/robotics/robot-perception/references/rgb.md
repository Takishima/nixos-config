# RGB Processing Pipelines

### Image Undistortion

```python
class ImageUndistorter:
    """Pre-compute undistortion maps for fast runtime correction.

    ALWAYS undistort before any geometric computation
    (pose estimation, 3D reconstruction, visual servoing).
    """

    def __init__(self, K, dist, image_size, alpha=0.0):
        """
        Args:
            alpha: 0.0 = crop all black pixels (default, recommended)
                   1.0 = keep all pixels (shows black borders)
        """
        self.new_K, self.roi = cv2.getOptimalNewCameraMatrix(
            K, dist, image_size, alpha, image_size)

        # Pre-compute maps (do this ONCE, not per frame)
        self.map1, self.map2 = cv2.initUndistortRectifyMap(
            K, dist, None, self.new_K, image_size, cv2.CV_16SC2)

    def undistort(self, image):
        """Apply undistortion using pre-computed maps (fast)"""
        return cv2.remap(image, self.map1, self.map2,
                         interpolation=cv2.INTER_LINEAR)

    def undistort_points(self, points_2d):
        """Undistort 2D point coordinates"""
        return cv2.undistortPoints(
            points_2d.reshape(-1, 1, 2).astype(np.float64),
            self.K, self.dist, P=self.new_K
        ).reshape(-1, 2)
```

### Object Detection Integration

```python
class RobotObjectDetector:
    """Object detection for robotic manipulation.

    Wraps a detection model with robotics-specific post-processing:
    - Workspace filtering (ignore detections outside robot reach)
    - Stability tracking (reject flickering detections)
    - 3D pose estimation from 2D detections + depth
    """

    def __init__(self, model, K, workspace_bounds=None, min_confidence=0.5):
        self.model = model
        self.K = K
        self.workspace_bounds = workspace_bounds
        self.min_confidence = min_confidence
        self.tracker = DetectionTracker(max_age=5, min_hits=3)

    def detect(self, rgb, depth=None) -> list:
        """Run detection with robotics post-processing"""
        # Raw detection
        raw_dets = self.model(rgb)

        # Filter by confidence
        dets = [d for d in raw_dets if d.confidence >= self.min_confidence]

        # Estimate 3D position if depth is available
        if depth is not None:
            for det in dets:
                det.position_3d = self._backproject(det.center, depth)

                # Filter by workspace
                if self.workspace_bounds and det.position_3d is not None:
                    if not self.workspace_bounds.contains(det.position_3d):
                        det.in_workspace = False
                        continue
                    det.in_workspace = True

        # Track across frames for stability
        tracked = self.tracker.update(dets)

        return tracked

    def _backproject(self, pixel, depth_image):
        """Convert 2D pixel + depth to 3D point in camera frame.

        This is the INVERSE of projection:
        X = (u - cx) * Z / fx
        Y = (v - cy) * Z / fy
        Z = depth
        """
        u, v = int(pixel[0]), int(pixel[1])

        # Sample depth with a small window (more robust than single pixel)
        h, w = depth_image.shape[:2]
        u = np.clip(u, 2, w - 3)
        v = np.clip(v, 2, h - 3)
        patch = depth_image[v-2:v+3, u-2:u+3]

        # Use median to reject outliers (holes, edges)
        valid = patch[patch > 0]
        if len(valid) == 0:
            return None
        Z = np.median(valid)

        # Convert from depth sensor units (often mm) to meters
        if Z > 100:  # Likely millimeters
            Z = Z / 1000.0

        fx, fy = self.K[0, 0], self.K[1, 1]
        cx, cy = self.K[0, 2], self.K[1, 2]

        X = (u - cx) * Z / fx
        Y = (v - cy) * Z / fy

        return np.array([X, Y, Z])
```

### Fiducial Marker Detection (AprilTag / ArUco)

```python
class FiducialDetector:
    """Detect and estimate pose of fiducial markers.

    Use cases:
    - Robot localization (known marker positions)
    - Object pose estimation (marker attached to object)
    - Calibration targets
    - Sim-to-real ground truth
    """

    def __init__(self, K, dist, marker_size_m=0.05,
                 dictionary=cv2.aruco.DICT_APRILTAG_36h11):
        self.K = K
        self.dist = dist
        self.marker_size = marker_size_m
        self.aruco_dict = cv2.aruco.getPredefinedDictionary(dictionary)
        self.params = cv2.aruco.DetectorParameters()
        self.detector = cv2.aruco.ArucoDetector(self.aruco_dict, self.params)

    def detect(self, image) -> list:
        """Detect markers and estimate their 6DOF poses"""
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        corners, ids, rejected = self.detector.detectMarkers(gray)

        results = []
        if ids is not None:
            for i, marker_id in enumerate(ids.flatten()):
                # Estimate pose (rotation + translation)
                rvecs, tvecs, _ = cv2.aruco.estimatePoseSingleMarkers(
                    corners[i:i+1], self.marker_size, self.K, self.dist)

                R, _ = cv2.Rodrigues(rvecs[0])
                T = np.eye(4)
                T[:3, :3] = R
                T[:3, 3] = tvecs[0].flatten()

                results.append(MarkerDetection(
                    marker_id=int(marker_id),
                    corners=corners[i].reshape(4, 2),
                    pose=T,
                    distance=np.linalg.norm(tvecs[0]),
                ))

        return results

    def draw(self, image, detections):
        """Visualize detected markers with axes"""
        vis = image.copy()
        for det in detections:
            cv2.aruco.drawDetectedMarkers(
                vis, [det.corners.reshape(1, 4, 2)],
                np.array([[det.marker_id]]))
            rvec, _ = cv2.Rodrigues(det.pose[:3, :3])
            cv2.drawFrameAxes(
                vis, self.K, self.dist, rvec,
                det.pose[:3, 3], self.marker_size * 0.5)
        return vis
```

### Semantic Segmentation for Manipulation

```python
class WorkspaceSegmenter:
    """Segment a robot's workspace into actionable regions.

    Common segmentation targets for manipulation:
    - Graspable objects vs background
    - Table / support surface
    - Robot body (for self-collision avoidance)
    - Free space vs obstacles
    """

    def __init__(self, model, class_map):
        self.model = model
        self.class_map = class_map  # {0: 'background', 1: 'table', 2: 'object', ...}

    def segment(self, rgb) -> SegmentationResult:
        """Run segmentation and extract per-class masks"""
        mask = self.model.predict(rgb)  # (H, W) with class IDs

        return SegmentationResult(
            full_mask=mask,
            object_mask=(mask == self.class_map['object']),
            table_mask=(mask == self.class_map['table']),
            free_space_mask=(mask == self.class_map['free_space']),
        )

    def get_grasp_candidates(self, rgb, depth, K):
        """Combine segmentation with depth to find graspable regions"""
        seg = self.segment(rgb)

        # Find connected components in object mask
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(
            seg.object_mask.astype(np.uint8))

        candidates = []
        for i in range(1, num_labels):  # Skip background (0)
            component_mask = (labels == i)
            area = stats[i, cv2.CC_STAT_AREA]

            if area < 100:  # Too small, likely noise
                continue

            # Get median depth of this object
            obj_depths = depth[component_mask]
            valid_depths = obj_depths[obj_depths > 0]
            if len(valid_depths) == 0:
                continue

            center_px = centroids[i]
            median_depth = np.median(valid_depths)

            # Backproject center to 3D
            fx, fy = K[0, 0], K[1, 1]
            cx, cy = K[0, 2], K[1, 2]
            X = (center_px[0] - cx) * median_depth / fx
            Y = (center_px[1] - cy) * median_depth / fy

            candidates.append(GraspCandidate(
                position_3d=np.array([X, Y, median_depth]),
                pixel_center=center_px,
                mask=component_mask,
                area_pixels=area,
            ))

        return candidates
```
