# Principle 5: Liskov Substitution — Replaceable Implementations

Any implementation of an interface must be substitutable without the caller knowing. If your code works with `ArmInterface`, it must work with ANY arm that implements it.

**Why it matters in robotics**: Sim-to-real transfer, hardware swaps, and multi-robot support all depend on this.

```python
# ❌ BAD: Violates substitution — caller must know the implementation
class FrankaArm(ArmInterface):
    def move_to_joints(self, positions, velocity=0.5):
        if len(positions) != 7:
            raise ValueError("Franka has 7 joints!")  # Franka-specific
        # ...

class UR5Arm(ArmInterface):
    def move_to_joints(self, positions, velocity=0.5):
        if len(positions) != 6:
            raise ValueError("UR5 has 6 joints!")  # UR5-specific
        # ...

# Caller must know which arm it's using to pass correct joint count!
# This breaks substitutability.

# ✅ GOOD: Self-describing implementations
class ArmInterface(ABC):
    @property
    @abstractmethod
    def num_joints(self) -> int: ...

    @property
    @abstractmethod
    def joint_limits(self) -> List[tuple]: ...

    @abstractmethod
    def move_to_joints(self, positions: np.ndarray, velocity: float = 0.5) -> bool:
        """Positions must have length == self.num_joints"""
        ...

class FrankaArm(ArmInterface):
    @property
    def num_joints(self): return 7

    def move_to_joints(self, positions, velocity=0.5):
        assert len(positions) == self.num_joints
        # ...

# Caller code is generic — works with any arm
def move_to_home(arm: ArmInterface):
    home = np.zeros(arm.num_joints)  # Queries the arm, doesn't assume
    arm.move_to_joints(home)
```

**Substitution test**: Take every line of caller code. Replace `UR5` with `Franka` with `SimArm`. Does it still work? If not, your abstraction leaks.

______________________________________________________________________
