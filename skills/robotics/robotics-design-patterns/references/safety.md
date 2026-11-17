# Pattern 6: Safety Systems

### The Safety Hierarchy

```
Level 0: Hardware E-Stop (physical button, cuts power)
Level 1: Safety-rated controller (SIL2/SIL3, hardware watchdog)
Level 2: Software watchdog (monitors heartbeats, enforces limits)
Level 3: Application safety (collision avoidance, workspace limits)
```

### Software Watchdog Pattern

```python
import threading
import time

class SafetyWatchdog:
    """Monitors system health and triggers safe stop on failures"""

    def __init__(self, timeout_ms=500):
        self.timeout = timeout_ms / 1000.0
        self.heartbeats = {}
        self.lock = threading.Lock()
        self.safe_stop_triggered = False

        # Start monitoring thread
        self.monitor_thread = threading.Thread(
            target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()

    def register_component(self, name: str, critical: bool = True):
        """Register a component that must send heartbeats"""
        with self.lock:
            self.heartbeats[name] = {
                'last_beat': time.monotonic(),
                'critical': critical,
                'alive': True
            }

    def heartbeat(self, name: str):
        """Called by components to signal they're alive"""
        with self.lock:
            if name in self.heartbeats:
                self.heartbeats[name]['last_beat'] = time.monotonic()
                self.heartbeats[name]['alive'] = True

    def _monitor_loop(self):
        while True:
            now = time.monotonic()
            with self.lock:
                for name, info in self.heartbeats.items():
                    elapsed = now - info['last_beat']
                    if elapsed > self.timeout and info['alive']:
                        info['alive'] = False
                        if info['critical']:
                            self._trigger_safe_stop(
                                f"Critical component '{name}' "
                                f"timed out ({elapsed:.1f}s)")
            time.sleep(self.timeout / 4)

    def _trigger_safe_stop(self, reason: str):
        if not self.safe_stop_triggered:
            self.safe_stop_triggered = True
            logger.critical(f"SAFE STOP: {reason}")
            self._execute_safe_stop()

    def _execute_safe_stop(self):
        """Bring robot to a safe state"""
        # 1. Stop all motion (zero velocity command)
        # 2. Engage brakes
        # 3. Publish emergency state to all nodes
        # 4. Log the event
        pass
```

### Workspace Limits

```python
class WorkspaceMonitor:
    """Enforce that robot stays within safe operational bounds"""

    def __init__(self, limits: dict):
        self.joint_limits = limits['joints']    # {joint: (min, max)}
        self.cartesian_bounds = limits['cartesian']  # AABB or convex hull
        self.velocity_limits = limits['velocity']
        self.force_limits = limits['force']

    def check_command(self, command) -> SafetyResult:
        """Validate a command BEFORE sending to hardware"""
        violations = []

        # Joint limit check
        for joint, value in command.joint_positions.items():
            lo, hi = self.joint_limits[joint]
            if not (lo <= value <= hi):
                violations.append(
                    f"Joint {joint}={value:.3f} outside [{lo:.3f}, {hi:.3f}]")

        # Velocity check
        for joint, vel in command.joint_velocities.items():
            if abs(vel) > self.velocity_limits[joint]:
                violations.append(
                    f"Joint {joint} velocity {vel:.3f} exceeds limit")

        if violations:
            return SafetyResult(safe=False, violations=violations)
        return SafetyResult(safe=True)
```
