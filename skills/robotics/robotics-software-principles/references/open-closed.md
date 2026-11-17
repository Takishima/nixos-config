# Principle 3: Open-Closed — Extend Without Modifying

Modules should be open for extension but closed for modification. Add new capabilities by adding new code, not changing existing code.

**Why it matters in robotics**: You constantly add new sensors, new robots, new tasks. If adding a new camera requires modifying your perception pipeline, you'll break existing deployments.

```python
# ❌ BAD: Adding a new sensor requires modifying existing code
class PerceptionPipeline:
    def process(self, sensor_type: str, data):
        if sensor_type == 'realsense':
            return self._process_realsense(data)
        elif sensor_type == 'zed':
            return self._process_zed(data)
        elif sensor_type == 'oakd':    # New sensor = modify this class
            return self._process_oakd(data)

# ✅ GOOD: Plugin architecture — add sensors without touching core
class SensorPlugin(ABC):
    """Base class for all sensor plugins"""
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def process(self, raw_data) -> ProcessedData: ...

    @abstractmethod
    def get_intrinsics(self) -> dict: ...


class RealSensePlugin(SensorPlugin):
    def name(self): return 'realsense'
    def process(self, raw_data):
        # RealSense-specific processing
        return ProcessedData(...)


class ZEDPlugin(SensorPlugin):
    def name(self): return 'zed'
    def process(self, raw_data):
        # ZED-specific processing
        return ProcessedData(...)


# Core pipeline never changes when you add sensors
class PerceptionPipeline:
    def __init__(self):
        self._plugins: dict[str, SensorPlugin] = {}

    def register_sensor(self, plugin: SensorPlugin):
        """Extend the pipeline without modifying it"""
        self._plugins[plugin.name()] = plugin

    def process(self, sensor_name: str, data):
        if sensor_name not in self._plugins:
            raise ValueError(f"Unknown sensor: {sensor_name}")
        return self._plugins[sensor_name].process(data)


# Adding OAK-D = add a file, register at startup. Zero changes to core.
class OAKDPlugin(SensorPlugin):
    def name(self): return 'oakd'
    def process(self, raw_data):
        return ProcessedData(...)

pipeline = PerceptionPipeline()
pipeline.register_sensor(RealSensePlugin())
pipeline.register_sensor(OAKDPlugin())  # No core code changed
```

______________________________________________________________________
