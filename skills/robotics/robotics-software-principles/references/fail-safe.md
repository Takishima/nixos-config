# Principle 7: Fail-Safe Defaults — Safe Until Proven Otherwise

Every module should default to the safest possible behavior. Safety is not a feature you add — it's the default you degrade from.

```python
# ❌ BAD: Unsafe defaults
class ArmController:
    def __init__(self):
        self.max_velocity = 3.14       # Full speed by default!
        self.collision_check = False    # Off by default!
        self.workspace_limits = None    # No limits by default!

# ✅ GOOD: Safe defaults — must explicitly opt into danger
class ArmController:
    def __init__(self):
        self.max_velocity = 0.1              # Crawl speed by default
        self.collision_check = True           # Always on
        self.workspace_limits = DEFAULT_SAFE_WORKSPACE  # Conservative box
        self.require_enable = True            # Must be explicitly enabled
        self._enabled = False

    def enable(self, operator_confirmed: bool = False):
        """Explicit enable step — requires operator confirmation for real hardware"""
        if not operator_confirmed and not self.is_simulation:
            raise SafetyError(
                "Real hardware requires operator confirmation to enable")
        self._enabled = True

    def move_to(self, target: np.ndarray, velocity: float = None):
        if not self._enabled:
            raise SafetyError("Controller not enabled")

        velocity = velocity or self.max_velocity

        # Clamp velocity to safe range
        velocity = min(velocity, self.max_velocity)

        # Check workspace limits BEFORE moving
        if not self.workspace_limits.contains(target):
            raise WorkspaceViolation(f"Target {target} outside safe workspace")

        # Check for collisions BEFORE moving
        if self.collision_check:
            if self.collision_detector.would_collide(target):
                raise CollisionRisk(f"Collision predicted for target {target}")

        return self._execute_move(target, velocity)
```

**The rule**: What happens when a module receives no input, invalid input, or loses communication? It should stop safely, not continue blindly.

```python
class SafetyDefaults:
    """Centralized safe defaults for the entire system"""

    # Communication loss → stop
    HEARTBEAT_TIMEOUT_MS = 500
    ACTION_ON_TIMEOUT = 'stop'           # Not 'continue_last_command'

    # Unknown state → stop
    ACTION_ON_UNKNOWN_STATE = 'stop'     # Not 'assume_safe'

    # Sensor failure → stop
    ACTION_ON_SENSOR_LOSS = 'stop'       # Not 'use_last_reading'

    # Joint limit approach → slow down
    JOINT_LIMIT_MARGIN_RAD = 0.05        # Stop 0.05 rad before limit
    VELOCITY_NEAR_LIMITS = 0.05          # Crawl near limits

    # Default workspace (conservative bounding box)
    WORKSPACE_MIN = np.array([-0.5, -0.5, 0.0])   # meters
    WORKSPACE_MAX = np.array([0.5, 0.5, 0.8])      # meters
```

______________________________________________________________________
