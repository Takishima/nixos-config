# Pattern 5: Hardware Abstraction Layer (HAL)

**Never let application code talk directly to hardware.** Always go through an abstraction layer.

```python
from abc import ABC, abstractmethod

class GripperInterface(ABC):
    """Abstract gripper interface — implement for each hardware type"""

    @abstractmethod
    def open(self, width: float = 1.0) -> bool: ...

    @abstractmethod
    def close(self, force: float = 0.5) -> bool: ...

    @abstractmethod
    def get_state(self) -> GripperState: ...

    @abstractmethod
    def get_width(self) -> float: ...


class RobotiqGripper(GripperInterface):
    """Concrete implementation for Robotiq 2F-85"""
    def __init__(self, port='/dev/ttyUSB0'):
        self.serial = serial.Serial(port, 115200)
        # ... Modbus RTU setup

    def close(self, force=0.5):
        cmd = self._build_modbus_cmd(force=int(force * 255))
        self.serial.write(cmd)
        return self._wait_for_completion()


class SimulatedGripper(GripperInterface):
    """Simulation gripper for testing"""
    def __init__(self):
        self.width = 0.085  # 85mm open
        self.state = GripperState.OPEN

    def close(self, force=0.5):
        self.width = 0.0
        self.state = GripperState.CLOSED
        return True


# Factory pattern for hardware instantiation
def create_gripper(config: dict) -> GripperInterface:
    gripper_type = config.get('type', 'simulated')
    if gripper_type == 'robotiq':
        return RobotiqGripper(port=config['port'])
    elif gripper_type == 'simulated':
        return SimulatedGripper()
    else:
        raise ValueError(f"Unknown gripper type: {gripper_type}")
```
