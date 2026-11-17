# Principle 9: Idempotent Operations — Safe to Retry

Every command should be safe to send twice. Network drops, message duplicates, and retries are facts of life in robotics.

```python
# ❌ BAD: Non-idempotent — sending twice moves the robot twice as far
def move_relative(self, delta: np.ndarray):
    current = self.get_position()
    self.move_to(current + delta)
    # If this message is sent twice due to a retry,
    # the robot moves 2x the intended distance!

# ✅ GOOD: Idempotent — sending twice has the same effect as once
def move_to_absolute(self, target: np.ndarray, command_id: str):
    if command_id == self._last_executed_command:
        return  # Already executed this command, skip
    self._last_executed_command = command_id
    self.move_to(target)
    # Sending this twice is harmless — same target, same result

# ✅ GOOD: Idempotent gripper commands
def set_gripper(self, width: float):
    """Set gripper to absolute width — not open/close toggle"""
    self.gripper.move_to_width(width)
    # Calling set_gripper(0.04) ten times still results in 0.04m width
```

______________________________________________________________________
