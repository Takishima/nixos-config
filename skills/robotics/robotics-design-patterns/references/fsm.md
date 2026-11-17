# Pattern 3: Finite State Machines (FSM)

Use FSMs for **simple, well-defined sequential behaviors** with clear states. Prefer BTs for anything complex.

```python
from enum import Enum, auto
import smach  # ROS state machine library

class RobotState(Enum):
    IDLE = auto()
    NAVIGATING = auto()
    PICKING = auto()
    PLACING = auto()
    ERROR = auto()
    CHARGING = auto()

# SMACH implementation
class NavigateState(smach.State):
    def __init__(self):
        smach.State.__init__(self,
            outcomes=['succeeded', 'aborted', 'preempted'],
            input_keys=['target_pose'],
            output_keys=['final_pose'])

    def execute(self, userdata):
        # Navigation logic
        result = navigate_to(userdata.target_pose)
        if result.success:
            userdata.final_pose = result.pose
            return 'succeeded'
        return 'aborted'

# Build state machine
sm = smach.StateMachine(outcomes=['done', 'failed'])
with sm:
    smach.StateMachine.add('NAVIGATE', NavigateState(),
        transitions={'succeeded': 'PICK', 'aborted': 'ERROR'})
    smach.StateMachine.add('PICK', PickState(),
        transitions={'succeeded': 'PLACE', 'aborted': 'ERROR'})
    smach.StateMachine.add('PLACE', PlaceState(),
        transitions={'succeeded': 'done', 'aborted': 'ERROR'})
    smach.StateMachine.add('ERROR', ErrorRecovery(),
        transitions={'recovered': 'NAVIGATE', 'fatal': 'failed'})
```

**When to use FSM vs BT**:

- FSM: Linear workflows, simple devices, UI states, protocol implementations
- BT: Complex robots, reactive behaviors, many conditional branches, reusable sub-behaviors
