# Principle 1: Single Responsibility — One Module, One Job

Every module (node, class, function) should have exactly ONE reason to change.

**Why it matters in robotics**: A perception module that also does control means a camera driver update can break your arm controller. In safety-critical systems, this coupling is unacceptable.

```python
# ❌ BAD: God module — perception + planning + control + logging
class RobotController:
    def __init__(self):
        self.camera = RealSenseCamera()
        self.detector = YOLODetector()
        self.planner = RRTPlanner()
        self.arm = UR5Driver()
        self.logger = DataLogger()

    def run(self):
        image = self.camera.capture()
        objects = self.detector.detect(image)
        path = self.planner.plan(objects[0].pose)
        self.arm.execute(path)
        self.logger.log(image, objects, path)
        # If ANY of these changes, you touch this class

# ✅ GOOD: Separated responsibilities with clear interfaces
class PerceptionModule:
    """ONLY responsibility: raw sensor data → detected objects"""
    def __init__(self, camera: CameraInterface, detector: DetectorInterface):
        self.camera = camera
        self.detector = detector

    def get_detections(self) -> List[Detection]:
        image = self.camera.capture()
        return self.detector.detect(image)

class PlanningModule:
    """ONLY responsibility: goal + world state → trajectory"""
    def __init__(self, planner: PlannerInterface):
        self.planner = planner

    def plan_to(self, target: Pose, obstacles: List[Obstacle]) -> Trajectory:
        return self.planner.plan(target, obstacles)

class ExecutionModule:
    """ONLY responsibility: trajectory → hardware commands"""
    def __init__(self, arm: ArmInterface):
        self.arm = arm

    def execute(self, trajectory: Trajectory) -> ExecutionResult:
        return self.arm.follow_trajectory(trajectory)
```

**Test**: Can you describe what a module does WITHOUT using "and"? If not, split it.

______________________________________________________________________
