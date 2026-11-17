# Principle 8: Configuration Over Code — Externalize Everything That Changes

Anything that might differ between deployments, robots, or environments should be in configuration, not code.

```python
# ❌ BAD: Hardcoded values scattered across files
class GraspPlanner:
    def plan(self, object_pose):
        approach_height = 0.15          # Magic number
        grasp_depth = 0.02              # Magic number
        if object_pose.z < 0.05:        # Magic number
            return None

# ✅ GOOD: Configuration-driven
# config/grasp_planner.yaml
# grasp_planner:
#   approach_height_m: 0.15
#   grasp_depth_m: 0.02
#   min_object_height_m: 0.05
#   max_grasp_width_m: 0.08
#   approach_velocity: 0.1
#   grasp_force_n: 10.0

@dataclass
class GraspConfig:
    approach_height_m: float = 0.15
    grasp_depth_m: float = 0.02
    min_object_height_m: float = 0.05
    max_grasp_width_m: float = 0.08
    approach_velocity: float = 0.1
    grasp_force_n: float = 10.0

    @classmethod
    def from_yaml(cls, path: str) -> 'GraspConfig':
        with open(path) as f:
            data = yaml.safe_load(f)
        return cls(**data.get('grasp_planner', {}))

    def validate(self):
        assert self.approach_height_m > 0, "Approach height must be positive"
        assert 0 < self.grasp_force_n < 100, "Force out of safe range"


class GraspPlanner:
    def __init__(self, config: GraspConfig):
        config.validate()
        self.config = config

    def plan(self, object_pose):
        if object_pose.z < self.config.min_object_height_m:
            return None
        # ...
```

**What goes in config**: robot IP addresses, joint limits, sensor parameters, safety thresholds, workspace boundaries, task-specific constants, file paths, feature flags.

**What stays in code**: algorithms, control logic, data structures, interface definitions, error handling.

______________________________________________________________________
