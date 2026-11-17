# Principle 6: Separation of Rates — Respect Timing Boundaries

Different subsystems run at different rates. Never couple them.

```
Component          Typical Rate     Criticality
─────────────────────────────────────────────────
Safety monitor     1000 Hz          HARD real-time
Joint controller   500-1000 Hz      HARD real-time
Trajectory exec    100-200 Hz       Firm real-time
State estimation   50-200 Hz        Firm real-time
Perception         10-30 Hz         Soft real-time
Planning           1-10 Hz          Best effort
Task management    0.1-1 Hz         Best effort
Logging            1-30 Hz          Best effort
UI/Dashboard       1-10 Hz          Best effort
```

```python
# ❌ BAD: Perception blocks the control loop
class Robot:
    def control_loop(self):  # Must run at 100Hz = 10ms budget
        image = self.camera.capture()           # 5ms
        objects = self.detector.detect(image)    # 200ms ← BLOCKS!
        pose = self.estimate_pose(objects)       # 2ms
        cmd = self.controller.compute(pose)      # 0.1ms
        self.arm.send_command(cmd)               # 0.5ms
        # Total: 207ms. Control runs at 5Hz instead of 100Hz!

# ✅ GOOD: Decoupled rates with async boundaries
class Robot:
    def __init__(self):
        self.latest_detections = []
        self.detection_lock = threading.Lock()

        # Perception runs in its own thread at its own rate
        self.perception_thread = threading.Thread(
            target=self._perception_loop, daemon=True)
        self.perception_thread.start()

    def _perception_loop(self):
        """Runs at ~10Hz — as fast as the detector allows"""
        while self.running:
            image = self.camera.capture()
            detections = self.detector.detect(image)
            with self.detection_lock:
                self.latest_detections = detections

    def control_loop(self):
        """Runs at 100Hz — NEVER blocked by perception"""
        rate = Rate(100)  # 10ms period
        while self.running:
            with self.detection_lock:
                detections = self.latest_detections  # Latest available

            pose = self.estimate_pose(detections)
            cmd = self.controller.compute(pose)
            self.arm.send_command(cmd)
            rate.sleep()
```

**Rule**: If subsystem A is slower than subsystem B, A must communicate to B via a buffer (topic, shared variable, queue) — never by direct call.

______________________________________________________________________
