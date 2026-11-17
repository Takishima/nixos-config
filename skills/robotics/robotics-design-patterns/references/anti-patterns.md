# Anti-Patterns to Avoid

### 1. God Node

**Problem**: One node does everything — perception, planning, control, logging.
**Fix**: Single responsibility. One node, one job. Connect via topics.

### 2. Hardcoded Magic Numbers

**Problem**: `if distance < 0.35:` scattered everywhere.
**Fix**: Parameters with descriptive names, loaded from config files.

### 3. Polling Instead of Events

**Problem**: `while True: check_sensor(); sleep(0.01)`
**Fix**: Use callbacks, subscribers, event-driven architecture.

### 4. No Error Recovery

**Problem**: Robot stops forever on first error.
**Fix**: Every action node needs a failure mode. Behavior trees with fallbacks.

### 5. Sim-Only Code

**Problem**: Code works perfectly in simulation, crashes on real hardware.
**Fix**: HAL pattern. Test with hardware-in-the-loop early and often.

### 6. No Timestamps

**Problem**: Sensor data without timestamps — impossible to fuse or replay.
**Fix**: Timestamp EVERYTHING at the source. Use monotonic clocks for control.

### 7. Blocking the Control Loop

**Problem**: Perception computation blocks the 100Hz control loop.
**Fix**: Separate processes/threads. Control loop must NEVER be blocked.

### 8. No Data Logging

**Problem**: Can't reproduce bugs, can't train models, can't audit behavior.
**Fix**: Always record. Event-based recording is cheap. Use MCAP format.
