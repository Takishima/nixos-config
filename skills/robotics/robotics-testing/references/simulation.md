# Simulation Testing

```python
class SimulationTestHarness:
    """Run behavior tests in simulation with deterministic physics"""

    def __init__(self, sim_config):
        self.sim = MuJoCoSimulator(sim_config)
        self.sim.set_seed(42)  # Deterministic physics

    def test_pick_and_place(self):
        """Full pick-and-place task in simulation"""
        # Setup scene
        self.sim.reset()
        self.sim.spawn_object('red_block', pose=[0.4, 0.1, 0.02])

        # Run behavior tree
        bt = create_pick_place_tree()
        bt.setup(sim=self.sim)

        max_steps = 1000
        for step in range(max_steps):
            bt.tick()
            self.sim.step()

            if bt.root.status == Status.SUCCESS:
                break

        # Verify outcome
        block_pose = self.sim.get_object_pose('red_block')
        target_pose = np.array([0.5, -0.1, 0.02])
        assert np.linalg.norm(block_pose[:3] - target_pose) < 0.02, \
            f"Block not at target: {block_pose[:3]} vs {target_pose}"
        assert step < max_steps - 1, "Task did not complete in time"

    def test_collision_safety(self):
        """Robot should never collide with table"""
        self.sim.reset()
        self.sim.spawn_object('obstacle', pose=[0.35, 0.0, 0.15])

        trajectory = planner.plan_with_obstacle(
            start=[0.3, -0.2, 0.3],
            goal=[0.3, 0.2, 0.3])

        for joints in trajectory:
            self.sim.set_joint_positions(joints)
            contacts = self.sim.get_contacts()
            robot_contacts = [c for c in contacts
                            if 'robot' in c.body1 or 'robot' in c.body2]
            assert len(robot_contacts) == 0, \
                f"Robot collision detected: {robot_contacts}"
```
