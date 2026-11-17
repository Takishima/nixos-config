# Camera Models and Calibration

### Pinhole Camera Model

```
                    3D World Point (X, Y, Z)
                           |
                    [R | t] — Extrinsic (world → camera)
                           |
                    Camera Point (Xc, Yc, Zc)
                           |
                    K — Intrinsic (camera → pixel)
                           |
                    Pixel (u, v)

K = [ fx   0   cx ]      fx, fy = focal lengths (pixels)
    [  0  fy   cy ]      cx, cy = principal point
    [  0   0    1 ]

Projection:  [u, v, 1]^T = K @ [R | t] @ [X, Y, Z, 1]^T
```

### Intrinsic Calibration

```python
import cv2
import numpy as np
from pathlib import Path

class IntrinsicCalibrator:
    """Camera intrinsic calibration using checkerboard pattern"""

    def __init__(self, board_size=(9, 6), square_size_m=0.025):
        self.board_size = board_size
        self.square_size = square_size_m

        # Prepare object points (3D coordinates of checkerboard corners)
        self.objp = np.zeros((board_size[0] * board_size[1], 3), np.float32)
        self.objp[:, :2] = np.mgrid[
            0:board_size[0], 0:board_size[1]
        ].T.reshape(-1, 2) * square_size_m

    def collect_calibration_images(self, camera, num_images=30,
                                    min_coverage=0.6):
        """Collect calibration images with good spatial coverage.

        IMPORTANT: Move the board to cover all regions of the image,
        including corners and edges. Tilt the board at various angles.
        Bad coverage = bad calibration, especially at image edges.
        """
        obj_points = []
        img_points = []
        coverage_map = np.zeros((4, 4), dtype=int)  # Track board positions

        while len(obj_points) < num_images:
            frame = camera.capture()
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            found, corners = cv2.findChessboardCorners(
                gray, self.board_size,
                cv2.CALIB_CB_ADAPTIVE_THRESH |
                cv2.CALIB_CB_NORMALIZE_IMAGE |
                cv2.CALIB_CB_FAST_CHECK
            )

            if found:
                # Sub-pixel refinement — critical for accuracy
                criteria = (cv2.TERM_CRITERIA_EPS +
                           cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)
                corners = cv2.cornerSubPix(
                    gray, corners, (11, 11), (-1, -1), criteria)

                # Track coverage
                center = corners.mean(axis=0).flatten()
                grid_x = int(center[0] / gray.shape[1] * 4)
                grid_y = int(center[1] / gray.shape[0] * 4)
                grid_x = min(grid_x, 3)
                grid_y = min(grid_y, 3)
                coverage_map[grid_y, grid_x] += 1

                obj_points.append(self.objp)
                img_points.append(corners)

        coverage = (coverage_map > 0).sum() / coverage_map.size
        if coverage < min_coverage:
            print(f"WARNING: Only {coverage:.0%} coverage. "
                  f"Move board to uncovered regions.")

        return obj_points, img_points, gray.shape[::-1]

    def calibrate(self, obj_points, img_points, image_size):
        """Run calibration and return camera matrix + distortion coeffs"""
        ret, K, dist, rvecs, tvecs = cv2.calibrateCamera(
            obj_points, img_points, image_size, None, None)

        if ret > 1.0:
            print(f"WARNING: High reprojection error ({ret:.3f} px). "
                  f"Check image quality and board detection.")

        # Compute per-image reprojection errors
        errors = []
        for i in range(len(obj_points)):
            projected, _ = cv2.projectPoints(
                obj_points[i], rvecs[i], tvecs[i], K, dist)
            err = cv2.norm(img_points[i], projected, cv2.NORM_L2)
            err /= len(projected)
            errors.append(err)

        print(f"Calibration complete:")
        print(f"  RMS reprojection error: {ret:.4f} px")
        print(f"  Per-image errors: mean={np.mean(errors):.4f}, "
              f"max={np.max(errors):.4f}")
        print(f"  Focal length: fx={K[0,0]:.1f}, fy={K[1,1]:.1f}")
        print(f"  Principal point: cx={K[0,2]:.1f}, cy={K[1,2]:.1f}")

        return CalibrationResult(
            camera_matrix=K, dist_coeffs=dist,
            rms_error=ret, image_size=image_size)

    def save(self, result, path):
        """Save calibration to YAML (OpenCV-compatible format)"""
        fs = cv2.FileStorage(str(path), cv2.FILE_STORAGE_WRITE)
        fs.write("camera_matrix", result.camera_matrix)
        fs.write("dist_coeffs", result.dist_coeffs)
        fs.write("image_width", result.image_size[0])
        fs.write("image_height", result.image_size[1])
        fs.write("rms_error", result.rms_error)
        fs.release()

    @staticmethod
    def load(path):
        """Load calibration from YAML"""
        fs = cv2.FileStorage(str(path), cv2.FILE_STORAGE_READ)
        K = fs.getNode("camera_matrix").mat()
        dist = fs.getNode("dist_coeffs").mat()
        w = int(fs.getNode("image_width").real())
        h = int(fs.getNode("image_height").real())
        fs.release()
        return CalibrationResult(
            camera_matrix=K, dist_coeffs=dist,
            image_size=(w, h), rms_error=0.0)
```

### Extrinsic Calibration (Camera-to-Camera, Camera-to-LiDAR)

```python
class ExtrinsicCalibrator:
    """Compute transform between two sensors using shared targets"""

    def calibrate_stereo(self, calib_left, calib_right,
                          obj_points, img_points_left, img_points_right,
                          image_size):
        """Stereo calibration: find relative pose between two cameras"""
        ret, K1, d1, K2, d2, R, T, E, F = cv2.stereoCalibrate(
            obj_points, img_points_left, img_points_right,
            calib_left.camera_matrix, calib_left.dist_coeffs,
            calib_right.camera_matrix, calib_right.dist_coeffs,
            image_size,
            flags=cv2.CALIB_FIX_INTRINSIC  # Use pre-calibrated intrinsics
        )

        print(f"Stereo calibration RMS: {ret:.4f} px")
        print(f"Baseline: {np.linalg.norm(T):.4f} m")

        return StereoCalibration(R=R, T=T, E=E, F=F, rms_error=ret)

    def calibrate_camera_to_lidar(self, camera_points_2d,
                                    lidar_points_3d, K, dist):
        """Find camera-to-LiDAR transform using corresponding points.

        Use a calibration target visible to both sensors (e.g.,
        checkerboard with reflective tape corners).
        """
        # PnP: find pose of 3D points relative to camera
        success, rvec, tvec = cv2.solvePnP(
            lidar_points_3d, camera_points_2d, K, dist,
            flags=cv2.SOLVEPNP_ITERATIVE
        )

        if not success:
            raise CalibrationError("PnP failed — check point correspondences")

        R, _ = cv2.Rodrigues(rvec)
        T_camera_lidar = np.eye(4)
        T_camera_lidar[:3, :3] = R
        T_camera_lidar[:3, 3] = tvec.flatten()

        # Verify by reprojecting
        projected, _ = cv2.projectPoints(
            lidar_points_3d, rvec, tvec, K, dist)
        error = np.mean(np.linalg.norm(
            camera_points_2d - projected.reshape(-1, 2), axis=1))
        print(f"Camera-LiDAR reprojection error: {error:.2f} px")

        return T_camera_lidar
```

### Hand-Eye Calibration (Camera-to-Robot)

```python
class HandEyeCalibrator:
    """Solve AX = XB for camera mounted on robot end-effector (eye-in-hand)
    or camera mounted on a fixed base (eye-to-hand).

    Requires moving the robot to multiple poses while observing a
    fixed calibration target.
    """

    def __init__(self, K, dist, board_size=(9, 6), square_size=0.025):
        self.K = K
        self.dist = dist
        self.board_size = board_size
        self.square_size = square_size
        self.objp = np.zeros((board_size[0] * board_size[1], 3), np.float32)
        self.objp[:, :2] = np.mgrid[
            0:board_size[0], 0:board_size[1]
        ].T.reshape(-1, 2) * square_size

    def collect_poses(self, camera, robot, num_poses=20):
        """Collect camera-target and robot poses at multiple configurations.

        IMPORTANT: Move to diverse robot orientations. At least 3 different
        rotation axes. Pure translations are NOT sufficient.
        """
        R_gripper2base = []
        t_gripper2base = []
        R_target2cam = []
        t_target2cam = []

        for i in range(num_poses):
            input(f"Move robot to pose {i+1}/{num_poses}, press Enter...")

            # Get robot end-effector pose
            ee_pose = robot.get_ee_pose()  # 4x4 homogeneous matrix
            R_gripper2base.append(ee_pose[:3, :3])
            t_gripper2base.append(ee_pose[:3, 3])

            # Detect calibration target in camera
            frame = camera.capture()
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            found, corners = cv2.findChessboardCorners(
                gray, self.board_size, None)

            if not found:
                print(f"  Board not detected at pose {i+1}, skip.")
                continue

            corners = cv2.cornerSubPix(
                gray, corners, (11, 11), (-1, -1),
                (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001))

            ret, rvec, tvec = cv2.solvePnP(
                self.objp, corners, self.K, self.dist)
            R, _ = cv2.Rodrigues(rvec)
            R_target2cam.append(R)
            t_target2cam.append(tvec.flatten())

        return (R_gripper2base, t_gripper2base,
                R_target2cam, t_target2cam)

    def calibrate_eye_in_hand(self, R_g2b, t_g2b, R_t2c, t_t2c):
        """Eye-in-hand: camera mounted on end-effector.
        Solves for T_camera_to_gripper."""
        R, t = cv2.calibrateHandEye(
            R_g2b, t_g2b, R_t2c, t_t2c,
            method=cv2.CALIB_HAND_EYE_TSAI  # Also: PARK, HORAUD, DANIILIDIS
        )
        T_cam2gripper = np.eye(4)
        T_cam2gripper[:3, :3] = R
        T_cam2gripper[:3, 3] = t.flatten()
        return T_cam2gripper

    def calibrate_eye_to_hand(self, R_g2b, t_g2b, R_t2c, t_t2c):
        """Eye-to-hand: camera fixed in workspace.
        Solves for T_camera_to_base."""
        # Invert robot poses (base-to-gripper → gripper-to-base)
        R_b2g = [R.T for R in R_g2b]
        t_b2g = [-R.T @ t for R, t in zip(R_g2b, t_g2b)]

        R, t = cv2.calibrateHandEye(
            R_b2g, t_b2g, R_t2c, t_t2c,
            method=cv2.CALIB_HAND_EYE_TSAI
        )
        T_cam2base = np.eye(4)
        T_cam2base[:3, :3] = R
        T_cam2base[:3, 3] = t.flatten()
        return T_cam2base

    def verify_calibration(self, T_cam2ee, robot, camera, target_points_3d):
        """Verify by projecting a known 3D point through the full chain.
        Error should be < 5mm for manipulation tasks."""
        ee_pose = robot.get_ee_pose()
        T_cam2base = ee_pose @ T_cam2ee

        # Project world point to camera
        point_in_cam = np.linalg.inv(T_cam2base) @ np.append(
            target_points_3d[0], 1.0)
        projected, _ = cv2.projectPoints(
            point_in_cam[:3].reshape(1, 3),
            np.zeros(3), np.zeros(3), self.K, self.dist)

        print(f"Verification projection: {projected.flatten()}")
        return projected.flatten()
```

### Calibration Quality Checklist

```
✅ Intrinsic calibration:
   - RMS reprojection error < 0.5 px (good), < 0.3 px (excellent)
   - ≥ 20 images with board covering full image area (corners + edges)
   - Board tilted at multiple angles (not just fronto-parallel)
   - Fixed focus / fixed zoom during calibration AND operation

✅ Extrinsic calibration (stereo / camera-LiDAR):
   - RMS < 1.0 px for stereo
   - Reprojection error < 3 px for camera-LiDAR
   - Verified with independent measurement (ruler / known distance)

✅ Hand-eye calibration:
   - ≥ 15 poses with diverse orientations (≥ 3 rotation axes)
   - Verification error < 5mm for manipulation, < 10mm for navigation
   - Robot repeatability accounted for (UR5 ≈ ±0.03mm, low-cost ≈ ±1mm)

⚠️  Recalibrate when:
   - Camera is physically bumped or remounted
   - Lens focus or zoom is changed
   - Temperature changes significantly (thermal expansion shifts intrinsics)
   - Robot is re-homed or joints are recalibrated
```
