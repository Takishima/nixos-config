# Pattern 1: The Robot Software Stack

Every robot system follows this layered architecture, regardless of complexity:

```
┌─────────────────────────────────────────────┐
│               APPLICATION LAYER              │
│    Mission planning, task allocation, UI     │
├─────────────────────────────────────────────┤
│              BEHAVIORAL LAYER                │
│  Behavior trees, FSMs, decision-making       │
├─────────────────────────────────────────────┤
│             FUNCTIONAL LAYER                 │
│  Perception, Planning, Control, Estimation   │
├─────────────────────────────────────────────┤
│           COMMUNICATION LAYER                │
│     ROS2, DDS, shared memory, IPC            │
├─────────────────────────────────────────────┤
│          HARDWARE ABSTRACTION LAYER          │
│    Drivers, sensor interfaces, actuators     │
├─────────────────────────────────────────────┤
│              HARDWARE LAYER                  │
│    Cameras, LiDARs, motors, grippers, IMUs   │
└─────────────────────────────────────────────┘
```

**Design Rule**: Information flows UP through perception, decisions flow DOWN through control. Never let the application layer directly command hardware.
