# Pattern 2: Behavior Trees (BT)

Behavior trees are the **recommended default** for robot decision-making. They're modular, reusable, and easier to debug than FSMs for complex behaviors.

### Core Node Types

```
Sequence (→)     : Execute children left-to-right, FAIL on first failure
Fallback (?)     : Execute children left-to-right, SUCCEED on first success
Parallel (⇉)     : Execute all children simultaneously
Decorator        : Modify a single child's behavior
Action (leaf)    : Execute a robot action
Condition (leaf) : Check a condition (no side effects)
```

### Example: Pick-and-Place BT

```
                    → Sequence
                   /    |      \
            → Check     → Pick     → Place
           /    \      /   |  \     /  |  \
       Battery  Obj  Open  Move  Close Move Open Release
       OK?    Found? Grip  To    Grip  To   Grip
                      per  Obj   per   Goal per
```

### Implementation Pattern

```python
import py_trees

class MoveToTarget(py_trees.behaviour.Behaviour):
    """Action node: Move robot to a target pose"""

    def __init__(self, name, target_key="target_pose"):
        super().__init__(name)
        self.target_key = target_key
        self.action_client = None

    def setup(self, **kwargs):
        """Called once when tree is set up — initialize resources"""
        self.node = kwargs.get('node')  # ROS2 node
        self.action_client = ActionClient(
            self.node, MoveBase, 'move_base')

    def initialise(self):
        """Called when this node first ticks — send the goal"""
        bb = self.blackboard
        target = bb.get(self.target_key)
        self.goal_handle = self.action_client.send_goal(target)
        self.logger.info(f"Moving to {target}")

    def update(self):
        """Called every tick — check progress"""
        if self.goal_handle is None:
            return py_trees.common.Status.FAILURE

        status = self.goal_handle.status
        if status == GoalStatus.STATUS_SUCCEEDED:
            return py_trees.common.Status.SUCCESS
        elif status == GoalStatus.STATUS_ABORTED:
            return py_trees.common.Status.FAILURE
        else:
            return py_trees.common.Status.RUNNING

    def terminate(self, new_status):
        """Called when node exits — cancel if preempted"""
        if new_status == py_trees.common.Status.INVALID:
            if self.goal_handle:
                self.goal_handle.cancel_goal()
                self.logger.info("Movement cancelled")

# Build the tree
def create_pick_place_tree():
    root = py_trees.composites.Sequence("PickAndPlace", memory=True)

    # Safety checks (Fallback: if any fails, abort)
    safety = py_trees.composites.Sequence("SafetyChecks", memory=False)
    safety.add_children([
        CheckBattery("BatteryOK", threshold=20.0),
        CheckEStop("EStopClear"),
    ])

    pick = py_trees.composites.Sequence("Pick", memory=True)
    pick.add_children([
        DetectObject("FindObject"),
        MoveToTarget("ApproachObject", target_key="object_pose"),
        GripperCommand("CloseGripper", action="close"),
    ])

    place = py_trees.composites.Sequence("Place", memory=True)
    place.add_children([
        MoveToTarget("MoveToPlace", target_key="place_pose"),
        GripperCommand("OpenGripper", action="open"),
    ])

    root.add_children([safety, pick, place])
    return root
```

### Blackboard Pattern

```python
# The Blackboard is the shared memory for BT nodes
bb = py_trees.blackboard.Blackboard()

# Perception nodes WRITE to blackboard
class DetectObject(py_trees.behaviour.Behaviour):
    def update(self):
        detections = self.perception.detect()
        if detections:
            self.blackboard.set("object_pose", detections[0].pose)
            self.blackboard.set("object_class", detections[0].label)
            return Status.SUCCESS
        return Status.FAILURE

# Action nodes READ from blackboard
class MoveToTarget(py_trees.behaviour.Behaviour):
    def initialise(self):
        target = self.blackboard.get("object_pose")
        self.send_goal(target)
```
