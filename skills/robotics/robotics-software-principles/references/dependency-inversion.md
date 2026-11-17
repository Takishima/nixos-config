# Principle 2: Dependency Inversion — Depend on Abstractions, Not Hardware

High-level modules (planning, behavior) should never depend on low-level modules (drivers, hardware). Both should depend on abstractions.

**Why it matters in robotics**: This is the foundation of sim-to-real. If your planner imports `UR5Driver` directly, it can't run in simulation. If it depends on `ArmInterface`, you swap implementations freely.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Optional
import numpy as np

# ─── ABSTRACTIONS (the contracts) ────────────────────────────

class ArmInterface(ABC):
    """Abstract arm — every arm implementation must honor this contract"""

    @abstractmethod
    def get_joint_positions(self) -> np.ndarray:
        """Returns current joint positions in radians"""
        ...

    @abstractmethod
    def get_ee_pose(self) -> Pose:
        """Returns current end-effector pose"""
        ...

    @abstractmethod
    def move_to_joints(self, positions: np.ndarray,
                        velocity: float = 0.5) -> bool:
        """Move to joint positions. Returns True on success."""
        ...

    @abstractmethod
    def stop(self) -> None:
        """Immediately stop all motion"""
        ...

    @property
    @abstractmethod
    def joint_limits(self) -> List[tuple]:
        """Returns [(min, max)] for each joint"""
        ...


class CameraInterface(ABC):
    """Abstract camera — any RGB camera must honor this"""

    @abstractmethod
    def capture(self) -> np.ndarray:
        """Returns (H, W, 3) uint8 RGB image"""
        ...

    @abstractmethod
    def get_intrinsics(self) -> CameraIntrinsics:
        """Returns camera intrinsic parameters"""
        ...

    @property
    @abstractmethod
    def resolution(self) -> tuple:
        """Returns (width, height)"""
        ...


class GripperInterface(ABC):
    @abstractmethod
    def open(self, width: float = 1.0) -> bool: ...

    @abstractmethod
    def close(self, force: float = 0.5) -> bool: ...

    @abstractmethod
    def get_width(self) -> float: ...

    @abstractmethod
    def is_grasping(self) -> bool: ...


# ─── CONCRETE IMPLEMENTATIONS ────────────────────────────────

class UR5Arm(ArmInterface):
    """Real UR5 via RTDE protocol"""
    def __init__(self, ip: str):
        self.rtde = RTDEControl(ip)
        self.rtde_receive = RTDEReceive(ip)

    def get_joint_positions(self) -> np.ndarray:
        return np.array(self.rtde_receive.getActualQ())

    def move_to_joints(self, positions, velocity=0.5):
        self.rtde.moveJ(positions.tolist(), velocity)
        return True

    def stop(self):
        self.rtde.stopScript()

    @property
    def joint_limits(self):
        return [(-2*np.pi, 2*np.pi)] * 6


class MuJoCoArm(ArmInterface):
    """Simulated arm in MuJoCo — SAME interface"""
    def __init__(self, model_path: str, joint_names: List[str]):
        self.model = mujoco.MjModel.from_xml_path(model_path)
        self.data = mujoco.MjData(self.model)
        self.joint_ids = [mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_JOINT, n)
                          for n in joint_names]

    def get_joint_positions(self) -> np.ndarray:
        return np.array([self.data.qpos[jid] for jid in self.joint_ids])

    def move_to_joints(self, positions, velocity=0.5):
        # Simulate motion with position control
        self.data.ctrl[:len(positions)] = positions
        for _ in range(100):
            mujoco.mj_step(self.model, self.data)
        return True

    def stop(self):
        self.data.ctrl[:] = 0


# ─── HIGH-LEVEL CODE DEPENDS ONLY ON ABSTRACTIONS ────────────

class PickPlaceTask:
    """This class works with ANY arm + gripper + camera.
    It never knows or cares if it's sim or real."""

    def __init__(self, arm: ArmInterface, gripper: GripperInterface,
                 camera: CameraInterface, detector: DetectorInterface):
        self.arm = arm
        self.gripper = gripper
        self.camera = camera
        self.detector = detector

    def execute(self, target_class: str) -> bool:
        image = self.camera.capture()
        detections = self.detector.detect(image)
        target = next((d for d in detections if d.label == target_class), None)
        if target is None:
            return False

        self.arm.move_to_joints(self.ik(target.pose))
        self.gripper.close()
        self.arm.move_to_joints(self.place_joints)
        self.gripper.open()
        return True
```

**The Dependency Rule in Robotics**:

```
Application / Tasks
    ↓ depends on
Interfaces (ABC)
    ↑ implements
Hardware Drivers / Simulators
```

Arrows point inward. High-level policy never imports low-level drivers.

______________________________________________________________________
