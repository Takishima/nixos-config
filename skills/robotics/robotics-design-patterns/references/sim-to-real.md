# Pattern 7: Sim-to-Real Architecture

```
┌────────────────────────────────────┐
│         Application Code           │
│  (Same code runs in sim AND real)  │
├──────────────┬─────────────────────┤
│   Sim HAL    │     Real HAL        │
│  (MuJoCo/    │  (Hardware          │
│   Gazebo/    │   drivers)          │
│   Isaac)     │                     │
└──────────────┴─────────────────────┘
```

**Key Principles**:

1. Application code NEVER knows if it's in sim or real
1. Same message types, same topic names, same interfaces
1. Use `use_sim_time` parameter to switch clock sources
1. Domain randomization happens INSIDE the sim HAL
1. Transfer learning adapters sit at the HAL boundary

```python
# Config-driven sim/real switching
class RobotDriver:
    def __init__(self, config):
        if config['mode'] == 'simulation':
            self.arm = SimulatedArm(config['sim'])
            self.camera = SimulatedCamera(config['sim'])
        elif config['mode'] == 'real':
            self.arm = UR5Driver(config['real']['arm_ip'])
            self.camera = RealSenseDriver(config['real']['camera_serial'])

        # Application code uses the same interface regardless
        self.perception = PerceptionPipeline(self.camera)
        self.planner = MotionPlanner(self.arm)
```
