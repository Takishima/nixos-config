# Sensor Streaming Best Practices

### Camera Streaming Architecture

```python
import threading
import time
from collections import deque
from dataclasses import dataclass, field
from typing import Optional
import numpy as np

@dataclass
class StampedFrame:
    """Frame with capture timestamp for synchronization"""
    data: np.ndarray
    timestamp: float          # time.monotonic() at capture
    sequence: int             # Frame counter
    sensor_id: str

class CameraStream:
    """Thread-safe camera streaming with bounded buffer.

    Design principles:
    1. Capture runs in a dedicated thread at sensor rate
    2. Processing never blocks capture
    3. Always use the LATEST frame (drop old ones for real-time)
    4. Timestamp at capture, not at processing time
    """

    def __init__(self, camera, buffer_size=2, name="camera"):
        self.camera = camera
        self.name = name
        self._buffer = deque(maxlen=buffer_size)
        self._lock = threading.Lock()
        self._new_frame = threading.Event()
        self._running = False
        self._sequence = 0
        self._thread = None

        # Diagnostics
        self._capture_times = deque(maxlen=100)
        self._drop_count = 0

    def start(self):
        """Start capture thread"""
        self._running = True
        self._thread = threading.Thread(
            target=self._capture_loop, daemon=True, name=f"{self.name}_capture")
        self._thread.start()

    def stop(self):
        """Stop capture thread"""
        self._running = False
        if self._thread:
            self._thread.join(timeout=2.0)

    def _capture_loop(self):
        while self._running:
            t_start = time.monotonic()

            try:
                raw = self.camera.capture()
                timestamp = time.monotonic()  # Timestamp AFTER capture

                frame = StampedFrame(
                    data=raw,
                    timestamp=timestamp,
                    sequence=self._sequence,
                    sensor_id=self.name
                )
                self._sequence += 1

                with self._lock:
                    if len(self._buffer) == self._buffer.maxlen:
                        self._drop_count += 1
                    self._buffer.append(frame)

                self._new_frame.set()
                self._capture_times.append(time.monotonic() - t_start)

            except Exception as e:
                print(f"[{self.name}] Capture error: {e}")
                time.sleep(0.01)  # Back off on error

    def get_latest(self) -> Optional[StampedFrame]:
        """Get most recent frame (non-blocking). Returns None if empty."""
        with self._lock:
            if self._buffer:
                return self._buffer[-1]
        return None

    def wait_for_frame(self, timeout=1.0) -> Optional[StampedFrame]:
        """Block until a new frame arrives"""
        self._new_frame.clear()
        if self._new_frame.wait(timeout=timeout):
            return self.get_latest()
        return None

    def get_diagnostics(self) -> dict:
        """Streaming health metrics"""
        if self._capture_times:
            times = list(self._capture_times)
            fps = 1.0 / np.mean(times) if np.mean(times) > 0 else 0
        else:
            fps = 0
        return {
            "sensor": self.name,
            "fps": round(fps, 1),
            "frames_captured": self._sequence,
            "frames_dropped": self._drop_count,
            "buffer_size": len(self._buffer),
            "avg_capture_ms": round(np.mean(times) * 1000, 1) if self._capture_times else 0,
        }
```

### Multi-Sensor Synchronization

```python
class SyncedMultiSensor:
    """Synchronize frames from multiple sensors by timestamp.

    Uses nearest-neighbor matching within a time tolerance.
    For hardware-synced sensors, use hardware trigger instead.
    """

    def __init__(self, sensors: dict, max_time_diff_ms=33):
        """
        Args:
            sensors: {"rgb": CameraStream, "depth": CameraStream, ...}
            max_time_diff_ms: Maximum allowed time difference between
                              synced frames. Default 33ms (1 frame at 30Hz).
        """
        self.sensors = sensors
        self.max_dt = max_time_diff_ms / 1000.0
        self._synced_callback = None

    def start(self):
        for s in self.sensors.values():
            s.start()

    def stop(self):
        for s in self.sensors.values():
            s.stop()

    def get_synced(self) -> Optional[dict]:
        """Get time-synchronized frames from all sensors.
        Returns None if any sensor is missing or too far out of sync."""
        frames = {}
        for name, stream in self.sensors.items():
            frame = stream.get_latest()
            if frame is None:
                return None
            frames[name] = frame

        # Check time alignment against the first sensor
        ref_time = list(frames.values())[0].timestamp
        for name, frame in frames.items():
            dt = abs(frame.timestamp - ref_time)
            if dt > self.max_dt:
                return None  # Out of sync

        return frames

    def get_synced_interpolated(self) -> Optional[dict]:
        """For sensors at different rates, interpolate to common timestamp.
        Useful for IMU + camera fusion."""
        # Get latest from each sensor
        frames = {}
        for name, stream in self.sensors.items():
            frame = stream.get_latest()
            if frame is None:
                return None
            frames[name] = frame

        # Use the SLOWEST sensor's timestamp as reference
        ref_time = min(f.timestamp for f in frames.values())

        result = {}
        for name, frame in frames.items():
            dt = frame.timestamp - ref_time
            if abs(dt) <= self.max_dt:
                result[name] = frame
            # For high-rate sensors (IMU), could interpolate here

        return result if len(result) == len(self.sensors) else None
```

### Hardware-Triggered Synchronization

```python
class HardwareSyncConfig:
    """Configure hardware trigger for multi-camera synchronization.

    ALWAYS prefer hardware sync over software sync for:
    - Stereo depth computation
    - Multi-camera 3D reconstruction
    - Fast-moving scenes

    Common trigger methods:
    - GPIO pulse from microcontroller (Arduino, ESP32)
    - Camera's own sync output → other cameras' trigger input
    - PTP (Precision Time Protocol) for GigE cameras
    """

    @staticmethod
    def setup_realsense_sync(master_serial, slave_serials):
        """Configure RealSense hardware sync (Inter-Cam sync mode)"""
        import pyrealsense2 as rs

        # Master camera: generates sync signal
        master = rs.pipeline()
        master_cfg = rs.config()
        master_cfg.enable_device(master_serial)
        master_sensor = master.start(master_cfg)

        # Set master to mode 1 (master)
        depth_sensor = master_sensor.get_device().first_depth_sensor()
        depth_sensor.set_option(rs.option.inter_cam_sync_mode, 1)

        # Slave cameras: receive sync signal
        slaves = []
        for serial in slave_serials:
            pipe = rs.pipeline()
            cfg = rs.config()
            cfg.enable_device(serial)
            profile = pipe.start(cfg)
            sensor = profile.get_device().first_depth_sensor()
            sensor.set_option(rs.option.inter_cam_sync_mode, 2)  # Slave
            slaves.append(pipe)

        return master, slaves

    @staticmethod
    def setup_ptp_sync(camera_ips):
        """Enable PTP synchronization for GigE Vision cameras.

        Requires PTP-capable network switch.
        Achieves < 1μs sync accuracy.
        """
        # Example with Basler/pylon cameras
        # import pypylon.pylon as py
        #
        # for ip in camera_ips:
        #     cam = py.InstantCamera(py.TlFactory.GetInstance()
        #         .CreateDevice(py.CDeviceInfo().SetIpAddress(ip)))
        #     cam.Open()
        #     cam.GevIEEE1588.Value = True  # Enable PTP
        #     cam.Close()
        pass
```

### Streaming Anti-Patterns

```python
# ❌ BAD: Capture and process in same thread — limits to slowest operation
def bad_pipeline():
    while True:
        frame = camera.capture()           # 5ms
        detections = model.detect(frame)   # 100ms
        # Effective rate: ~9 FPS regardless of camera's 30 FPS

# ✅ GOOD: Decouple capture from processing
def good_pipeline():
    stream = CameraStream(camera)
    stream.start()
    while True:
        frame = stream.get_latest()        # Always latest, non-blocking
        if frame:
            detections = model.detect(frame.data)  # 100ms
            # Camera still capturing at 30 FPS in background
            # Processing at ~10 FPS but always on freshest frame


# ❌ BAD: Unbounded buffer — memory grows until OOM
buffer = []  # Will grow forever if consumer is slower than producer!

# ✅ GOOD: Bounded buffer with drop policy
buffer = deque(maxlen=2)  # Keep latest 2, drop old automatically


# ❌ BAD: Sleeping for frame timing
time.sleep(1.0 / 30)  # Drift accumulates, doesn't account for jitter

# ✅ GOOD: Event-driven or spin with wall clock
frame = stream.wait_for_frame(timeout=0.1)


# ❌ BAD: Timestamp at processing time
def process_callback(raw_data):
    timestamp = time.time()  # WRONG: includes queue delay + scheduling
    frame = decode(raw_data)
    publish(frame, timestamp)

# ✅ GOOD: Timestamp at capture time
def capture_thread():
    raw_data = sensor.read()
    timestamp = time.monotonic()  # RIGHT: timestamp at source
    queue.put((raw_data, timestamp))
```
