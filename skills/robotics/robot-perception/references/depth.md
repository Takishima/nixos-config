# Depth Processing

### Depth Map Filtering and Cleanup

```python
class DepthProcessor:
    """Clean up raw depth maps for downstream use.

    Raw depth from sensors is noisy: holes, flying pixels at edges,
    multi-path interference, and range noise. Always filter before use.
    """

    def __init__(self, depth_scale=0.001, min_depth_m=0.1, max_depth_m=3.0):
        self.depth_scale = depth_scale  # Raw units to meters
        self.min_depth = min_depth_m
        self.max_depth = max_depth_m

    def process(self, raw_depth) -> np.ndarray:
        """Full depth cleanup pipeline"""
        depth = raw_depth.astype(np.float32) * self.depth_scale

        # 1. Range filtering
        depth[(depth < self.min_depth) | (depth > self.max_depth)] = 0

        # 2. Edge filtering — remove flying pixels at depth discontinuities
        depth = self._remove_flying_pixels(depth)

        # 3. Hole filling — fill small holes via inpainting
        depth = self._fill_holes(depth, max_hole_size=10)

        # 4. Spatial smoothing — bilateral filter preserves edges
        depth = self._bilateral_filter(depth)

        return depth

    def _remove_flying_pixels(self, depth, threshold=0.05):
        """Remove pixels at depth discontinuities (flying pixels).
        These are artifacts where the sensor interpolates between
        foreground and background."""
        dx = np.abs(np.diff(depth, axis=1, prepend=0))
        dy = np.abs(np.diff(depth, axis=0, prepend=0))
        gradient = np.sqrt(dx**2 + dy**2)
        depth[gradient > threshold] = 0
        return depth

    def _fill_holes(self, depth, max_hole_size=10):
        """Fill small holes using inpainting. Large holes remain as 0."""
        mask = (depth == 0).astype(np.uint8)

        # Only fill small holes
        kernel = np.ones((max_hole_size, max_hole_size), np.uint8)
        small_holes = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
        small_holes = small_holes & mask

        if small_holes.any():
            # Normalize depth to uint16 for inpainting
            d_norm = (depth * 1000).astype(np.uint16)
            filled = cv2.inpaint(
                d_norm, small_holes, max_hole_size, cv2.INPAINT_NS)
            depth = np.where(small_holes, filled.astype(np.float32) / 1000, depth)

        return depth

    def _bilateral_filter(self, depth, d=5, sigma_color=0.02, sigma_space=5):
        """Bilateral filter: smooths noise while preserving depth edges"""
        # Convert to uint16 for cv2 bilateral (doesn't support float)
        d_uint16 = (depth * 10000).astype(np.uint16)
        filtered = cv2.bilateralFilter(d_uint16, d,
                                        sigma_color * 10000, sigma_space)
        return filtered.astype(np.float32) / 10000
```

### Depth-to-Point Cloud Conversion

```python
class DepthToPointCloud:
    """Convert depth images to organized and unorganized point clouds."""

    def __init__(self, K, image_size):
        self.K = K
        # Pre-compute pixel coordinate grid (do once, reuse every frame)
        h, w = image_size[1], image_size[0]
        u_coords, v_coords = np.meshgrid(np.arange(w), np.arange(h))
        self.u = u_coords.astype(np.float32)
        self.v = v_coords.astype(np.float32)
        self.fx, self.fy = K[0, 0], K[1, 1]
        self.cx, self.cy = K[0, 2], K[1, 2]

    def convert(self, depth, rgb=None) -> np.ndarray:
        """Convert depth image to point cloud.

        Returns:
            points: (N, 3) or (N, 6) if rgb provided [x, y, z, r, g, b]
        """
        # Backproject all pixels in parallel (vectorized)
        Z = depth.astype(np.float32)
        X = (self.u - self.cx) * Z / self.fx
        Y = (self.v - self.cy) * Z / self.fy

        # Stack into (H, W, 3) organized point cloud
        points = np.stack([X, Y, Z], axis=-1)

        # Filter invalid points
        valid_mask = Z > 0
        points_valid = points[valid_mask]

        if rgb is not None:
            colors = rgb[valid_mask].astype(np.float32) / 255.0
            return np.hstack([points_valid, colors])

        return points_valid

    def convert_organized(self, depth, rgb=None):
        """Return organized point cloud (H, W, 3) — preserves pixel layout.
        Invalid points are NaN."""
        Z = depth.astype(np.float32)
        X = (self.u - self.cx) * Z / self.fx
        Y = (self.v - self.cy) * Z / self.fy

        organized = np.stack([X, Y, Z], axis=-1)
        organized[depth == 0] = np.nan

        return organized
```

### RGBD Alignment

```python
class RGBDAligner:
    """Align RGB and depth images from different sensors.

    Most RGBD sensors (RealSense, ZED) provide built-in alignment.
    Use this when combining separate RGB + depth cameras.
    """

    def __init__(self, K_rgb, K_depth, T_depth_to_rgb, rgb_size, depth_size):
        self.K_rgb = K_rgb
        self.K_depth = K_depth
        self.T = T_depth_to_rgb  # 4x4 transform: depth frame → rgb frame
        self.rgb_size = rgb_size
        self.depth_size = depth_size

    def align_depth_to_rgb(self, depth):
        """Reproject depth image into RGB camera's frame.

        For each pixel in depth image:
        1. Backproject to 3D using depth intrinsics
        2. Transform to RGB camera frame
        3. Project to RGB pixel using RGB intrinsics
        """
        h_d, w_d = depth.shape
        h_r, w_r = self.rgb_size[1], self.rgb_size[0]
        aligned = np.zeros((h_r, w_r), dtype=np.float32)

        # Backproject depth pixels to 3D
        v_d, u_d = np.mgrid[0:h_d, 0:w_d].astype(np.float32)
        Z = depth.astype(np.float32)
        valid = Z > 0

        X = (u_d[valid] - self.K_depth[0, 2]) * Z[valid] / self.K_depth[0, 0]
        Y = (v_d[valid] - self.K_depth[1, 2]) * Z[valid] / self.K_depth[1, 1]
        pts_3d = np.stack([X, Y, Z[valid], np.ones_like(X)], axis=0)

        # Transform to RGB frame
        pts_rgb = self.T @ pts_3d

        # Project to RGB pixels
        u_r = (self.K_rgb[0, 0] * pts_rgb[0] / pts_rgb[2] +
               self.K_rgb[0, 2]).astype(int)
        v_r = (self.K_rgb[1, 1] * pts_rgb[1] / pts_rgb[2] +
               self.K_rgb[1, 2]).astype(int)

        # Fill aligned depth (z-buffer for occlusion handling)
        in_bounds = (u_r >= 0) & (u_r < w_r) & (v_r >= 0) & (v_r < h_r)
        for u, v, z in zip(u_r[in_bounds], v_r[in_bounds],
                           pts_rgb[2][in_bounds]):
            if aligned[v, u] == 0 or z < aligned[v, u]:
                aligned[v, u] = z

        return aligned
```
