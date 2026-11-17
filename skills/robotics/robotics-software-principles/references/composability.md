# Principle 11: Composability — Build Complex Behaviors from Simple Ones

Design modules as composable building blocks. Complex robot behaviors should emerge from combining simple, tested primitives.

```python
# Primitive skills — simple, tested, reusable
class MoveTo(Skill):
    """Move end-effector to a target pose"""
    def execute(self, target: Pose) -> bool: ...

class Grasp(Skill):
    """Close gripper with force control"""
    def execute(self, force: float = 10.0) -> bool: ...

class Release(Skill):
    """Open gripper"""
    def execute(self) -> bool: ...

class LookAt(Skill):
    """Point camera at a target"""
    def execute(self, target: Point) -> bool: ...

class Detect(Skill):
    """Detect objects of a given class"""
    def execute(self, target_class: str) -> List[Detection]: ...


# Composite skills — built from primitives
class Pick(CompositeSkill):
    """Pick = Detect + MoveTo + Grasp"""
    def __init__(self, detect: Detect, move: MoveTo, grasp: Grasp):
        self.detect = detect
        self.move = move
        self.grasp = grasp

    def execute(self, object_class: str) -> bool:
        detections = self.detect.execute(object_class)
        if not detections:
            return False
        approach = compute_approach_pose(detections[0].pose)
        if not self.move.execute(approach):
            return False
        if not self.move.execute(detections[0].pose):
            return False
        return self.grasp.execute()


class Place(CompositeSkill):
    """Place = MoveTo + Release"""
    def __init__(self, move: MoveTo, release: Release):
        self.move = move
        self.release = release

    def execute(self, target: Pose) -> bool:
        if not self.move.execute(target):
            return False
        return self.release.execute()


class PickAndPlace(CompositeSkill):
    """PickAndPlace = Pick + Place — composed from compositions"""
    def __init__(self, pick: Pick, place: Place):
        self.pick = pick
        self.place = place

    def execute(self, object_class: str, target: Pose) -> bool:
        if not self.pick.execute(object_class):
            return False
        return self.place.execute(target)


# Dependency injection wires everything together at startup
def build_skill_library(arm, gripper, camera, detector):
    move = MoveTo(arm)
    grasp = Grasp(gripper)
    release = Release(gripper)
    look = LookAt(arm)
    detect = Detect(camera, detector)
    pick = Pick(detect, move, grasp)
    place = Place(move, release)
    pick_and_place = PickAndPlace(pick, place)
    return {
        'move': move, 'grasp': grasp, 'release': release,
        'pick': pick, 'place': place,
        'pick_and_place': pick_and_place,
    }
```

______________________________________________________________________
