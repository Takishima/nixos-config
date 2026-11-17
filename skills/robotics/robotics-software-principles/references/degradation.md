# Principle 12: Graceful Degradation — Work With What You Have

When components fail, the robot should degrade gracefully rather than stop entirely.

```python
class DegradedModeManager:
    """Manages capability degradation as components fail"""

    def __init__(self):
        self.capabilities = {
            'full_autonomy': {'requires': ['camera', 'lidar', 'arm', 'gripper']},
            'blind_manipulation': {'requires': ['arm', 'gripper']},
            'perception_only': {'requires': ['camera', 'lidar']},
            'safe_stop': {'requires': []},
        }
        self.active_components = set()

    def component_online(self, name: str):
        self.active_components.add(name)
        self._update_mode()

    def component_offline(self, name: str):
        self.active_components.discard(name)
        logger.warning(f"Component offline: {name}")
        self._update_mode()

    def _update_mode(self):
        """Find the best mode we can support with available components"""
        for mode, spec in self.capabilities.items():
            if set(spec['requires']).issubset(self.active_components):
                if mode != self.current_mode:
                    logger.info(f"Mode change: {self.current_mode} → {mode}")
                    self.current_mode = mode
                return
        self.current_mode = 'safe_stop'
        self._execute_safe_stop()
```

______________________________________________________________________
