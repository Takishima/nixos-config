# Golden File Testing (Trajectory Regression)

```python
class TestTrajectoryRegression:
    """Compare planner output against known-good trajectories"""

    GOLDEN_DIR = Path(__file__).parent / 'golden_trajectories'

    def test_straight_line_plan(self):
        start = np.array([0.3, 0.0, 0.5])
        goal = np.array([0.5, 0.2, 0.3])

        trajectory = planner.plan(start, goal)

        golden_file = self.GOLDEN_DIR / 'straight_line.npy'
        if not golden_file.exists():
            # First run: save as golden
            np.save(golden_file, trajectory)
            pytest.skip("Golden file created — re-run to test")

        golden = np.load(golden_file)
        np.testing.assert_allclose(trajectory, golden, atol=1e-4,
            err_msg="Trajectory regression! Planner output changed.")

    def test_obstacle_avoidance_plan(self):
        start = np.array([0.3, 0.0, 0.5])
        goal = np.array([0.5, 0.2, 0.3])
        obstacles = [Sphere(center=[0.4, 0.1, 0.4], radius=0.05)]

        trajectory = planner.plan(start, goal, obstacles=obstacles)

        # Verify no collisions
        for point in trajectory:
            for obs in obstacles:
                dist = np.linalg.norm(point[:3] - obs.center)
                assert dist > obs.radius, \
                    f"Collision at {point[:3]}, dist={dist:.4f}"
```
