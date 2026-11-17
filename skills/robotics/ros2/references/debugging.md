# Debugging Toolkit

```bash
# Topic inspection
ros2 topic list
ros2 topic info /camera/image_raw -v  # Shows QoS details
ros2 topic hz /camera/image_raw
ros2 topic bw /camera/image_raw
ros2 topic echo /joint_states --once

# Node inspection
ros2 node list
ros2 node info /perception

# Parameter management
ros2 param list /perception
ros2 param get /perception confidence_threshold
ros2 param set /perception confidence_threshold 0.8  # Runtime change!

# Lifecycle management
ros2 lifecycle list /managed_perception
ros2 lifecycle set /managed_perception configure
ros2 lifecycle set /managed_perception activate

# Service calls
ros2 service list
ros2 service call /get_pose my_interfaces/srv/GetPose "{}"

# Action monitoring
ros2 action list
ros2 action info /pick_place
ros2 action send_goal /pick_place my_interfaces/action/PickPlace "{target_pose: {x: 1.0}}"

# Bag recording (ROS2 style)
ros2 bag record -a                              # All topics
ros2 bag record /camera/image /tf               # Specific topics
ros2 bag record -s mcap /camera/image           # MCAP format (recommended)
ros2 bag info recording/                        # Inspect
ros2 bag play recording/ --clock                # Playback

# DDS debugging
ros2 doctor                                     # System diagnostics
ros2 daemon stop && ros2 daemon start           # Reset discovery daemon
```
