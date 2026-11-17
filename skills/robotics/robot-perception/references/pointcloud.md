# Point Cloud Processing

### Filtering and Downsampling

```python
import open3d as o3d

class PointCloudProcessor:
    """Point cloud processing pipeline using Open3D.

    Pipeline order matters:
    1. Crop to region of interest (reduces data volume first)
    2. Remove statistical outliers
    3. Downsample (voxel grid)
    4. Estimate normals
    5. Application-specific processing
    """

    def preprocess(self, points, colors=None,
                   workspace_bounds=None, voxel_size=0.005):
        """Standard preprocessing pipeline"""
        pcd = o3d.geometry.PointCloud()
        pcd.points = o3d.utility.Vector3dVector(points[:, :3])
        if colors is not None:
            pcd.colors = o3d.utility.Vector3dVector(colors)

        # 1. Crop to workspace
        if workspace_bounds:
            bbox = o3d.geometry.AxisAlignedBoundingBox(
                min_bound=workspace_bounds['min'],
                max_bound=workspace_bounds['max'])
            pcd = pcd.crop(bbox)

        # 2. Statistical outlier removal
        pcd, inlier_idx = pcd.remove_statistical_outlier(
            nb_neighbors=20, std_ratio=2.0)

        # 3. Voxel downsampling
        pcd = pcd.voxel_down_sample(voxel_size=voxel_size)

        # 4. Normal estimation
        pcd.estimate_normals(
            search_param=o3d.geometry.KDTreeSearchParamHybrid(
                radius=voxel_size * 4, max_nn=30))
        # Orient normals toward camera
        pcd.orient_normals_towards_camera_location(
            camera_location=np.array([0, 0, 0]))

        return pcd

    def segment_plane(self, pcd, distance_threshold=0.005,
                      ransac_n=3, num_iterations=1000):
        """Segment the dominant plane (table / floor) using RANSAC.
        Returns plane model and inlier/outlier point clouds."""
        plane_model, inliers = pcd.segment_plane(
            distance_threshold=distance_threshold,
            ransac_n=ransac_n,
            num_iterations=num_iterations)

        plane_cloud = pcd.select_by_index(inliers)
        objects_cloud = pcd.select_by_index(inliers, invert=True)

        a, b, c, d = plane_model
        print(f"Plane: {a:.3f}x + {b:.3f}y + {c:.3f}z + {d:.3f} = 0")

        return plane_model, plane_cloud, objects_cloud

    def cluster_objects(self, pcd, eps=0.02, min_points=50):
        """Cluster point cloud into individual objects using DBSCAN"""
        labels = np.array(pcd.cluster_dbscan(
            eps=eps, min_points=min_points, print_progress=False))

        clusters = []
        for label_id in range(labels.max() + 1):
            cluster_mask = labels == label_id
            cluster_pcd = pcd.select_by_index(
                np.where(cluster_mask)[0])

            bbox = cluster_pcd.get_axis_aligned_bounding_box()
            center = bbox.get_center()
            extent = bbox.get_extent()

            clusters.append(PointCloudCluster(
                cloud=cluster_pcd,
                centroid=center,
                extent=extent,
                num_points=cluster_mask.sum(),
                bbox=bbox,
            ))

        # Sort by size (largest first)
        clusters.sort(key=lambda c: c.num_points, reverse=True)
        return clusters
```

### Point Cloud Registration (ICP)

```python
class PointCloudRegistration:
    """Align two point clouds using ICP and its variants.

    Use cases:
    - Multi-view reconstruction (combine views from different poses)
    - Object model matching (align scan to CAD model)
    - LiDAR odometry (align consecutive scans)
    - Bin picking (match object template to scene)
    """

    def align_icp(self, source, target, initial_transform=np.eye(4),
                  max_distance=0.05, method='point_to_plane'):
        """Iterative Closest Point alignment.

        Args:
            source: point cloud to align
            target: reference point cloud
            initial_transform: starting guess (CRITICAL for convergence)
            max_distance: max correspondence distance
            method: 'point_to_point' or 'point_to_plane'
        """
        if method == 'point_to_plane':
            # Point-to-plane converges faster but needs normals
            if not target.has_normals():
                target.estimate_normals(
                    search_param=o3d.geometry.KDTreeSearchParamHybrid(
                        radius=0.05, max_nn=30))
            estimation = o3d.pipelines.registration.TransformationEstimationPointToPlane()
        else:
            estimation = o3d.pipelines.registration.TransformationEstimationPointToPoint()

        result = o3d.pipelines.registration.registration_icp(
            source, target, max_distance, initial_transform,
            estimation,
            o3d.pipelines.registration.ICPConvergenceCriteria(
                max_iteration=100,
                relative_fitness=1e-6,
                relative_rmse=1e-6))

        print(f"ICP fitness: {result.fitness:.4f}, "
              f"RMSE: {result.inlier_rmse:.6f}")

        if result.fitness < 0.3:
            print("WARNING: Low fitness — ICP likely failed. "
                  "Check initial alignment or increase max_distance.")

        return result.transformation, result

    def align_global(self, source, target, voxel_size=0.01):
        """Global registration (no initial guess needed).
        Use FPFH features + RANSAC for coarse alignment,
        then refine with ICP."""

        # Downsample for feature computation
        source_down = source.voxel_down_sample(voxel_size)
        target_down = target.voxel_down_sample(voxel_size)

        # Compute normals
        for pcd in [source_down, target_down]:
            pcd.estimate_normals(
                o3d.geometry.KDTreeSearchParamHybrid(
                    radius=voxel_size * 2, max_nn=30))

        # Compute FPFH features
        source_fpfh = o3d.pipelines.registration.compute_fpfh_feature(
            source_down,
            o3d.geometry.KDTreeSearchParamHybrid(
                radius=voxel_size * 5, max_nn=100))
        target_fpfh = o3d.pipelines.registration.compute_fpfh_feature(
            target_down,
            o3d.geometry.KDTreeSearchParamHybrid(
                radius=voxel_size * 5, max_nn=100))

        # RANSAC-based global registration
        coarse = o3d.pipelines.registration.registration_ransac_based_on_feature_matching(
            source_down, target_down, source_fpfh, target_fpfh,
            mutual_filter=True,
            max_correspondence_distance=voxel_size * 2,
            estimation_method=o3d.pipelines.registration.TransformationEstimationPointToPoint(),
            ransac_n=3,
            checkers=[
                o3d.pipelines.registration.CorrespondenceCheckerBasedOnEdgeLength(0.9),
                o3d.pipelines.registration.CorrespondenceCheckerBasedOnDistance(voxel_size * 2),
            ],
            criteria=o3d.pipelines.registration.RANSACConvergenceCriteria(100000, 0.999))

        # Refine with ICP
        refined, _ = self.align_icp(
            source, target,
            initial_transform=coarse.transformation,
            max_distance=voxel_size * 1.5,
            method='point_to_plane')

        return refined
```
