# Rate Limiting and Backpressure

### Server-Side Rate Limiting

```python
# rate_limiter.py — Token bucket rate limiter
import time
import threading


class TokenBucketRateLimiter:
    """Token bucket rate limiter for controlling message throughput.

    Usage:
        limiter = TokenBucketRateLimiter(tokens_per_second=10, burst_size=15)
        if limiter.acquire():
            send_message()
        else:
            drop_or_queue()
    """

    def __init__(self, tokens_per_second: float, burst_size: int = 0):
        self.rate = tokens_per_second
        self.burst_size = burst_size or int(tokens_per_second)
        self._tokens = float(self.burst_size)
        self._last_refill = time.monotonic()
        self._lock = threading.Lock()

    def acquire(self) -> bool:
        """Try to acquire a token. Returns True if allowed, False if rate limited."""
        with self._lock:
            now = time.monotonic()
            elapsed = now - self._last_refill
            self._tokens = min(
                self.burst_size,
                self._tokens + elapsed * self.rate
            )
            self._last_refill = now

            if self._tokens >= 1.0:
                self._tokens -= 1.0
                return True
            return False

    def reset(self):
        """Reset to full burst capacity."""
        with self._lock:
            self._tokens = float(self.burst_size)
            self._last_refill = time.monotonic()
```

### Client-Driven Backpressure

Let clients request their own rate to match their processing capability.

```python
@app.websocket("/ws/sensor/{topic_name}")
async def sensor_stream(websocket: WebSocket, topic_name: str):
    await websocket.accept()

    # Client sends desired rate on connect
    config = await websocket.receive_json()
    requested_hz = config.get("hz", 10)
    requested_hz = max(1, min(requested_hz, 30))  # Clamp to 1-30 Hz
    interval = 1.0 / requested_hz

    ros_node: RobotBridgeNode = websocket.app.state.ros_node

    try:
        while True:
            data = ros_node.get_latest_odom()
            if data:
                await websocket.send_json({"topic": topic_name, "data": data})
            await asyncio.sleep(interval)
    except WebSocketDisconnect:
        pass
```

### Adaptive Quality Reduction

Reduce image quality when bandwidth or client processing cannot keep up.

```python
# Adaptive quality — reduce JPEG quality when send buffer backs up
import cv2
import numpy as np


async def adaptive_camera_stream(websocket: WebSocket, ros_node: RobotBridgeNode):
    quality = 80  # Start at 80% JPEG quality
    send_times = []

    while True:
        image_bytes = ros_node.get_latest_image()
        if image_bytes is None:
            await asyncio.sleep(0.05)
            continue

        # Re-encode with adaptive quality if needed
        if quality < 80:
            np_arr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
            _, image_bytes = cv2.imencode(
                '.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, quality])
            image_bytes = image_bytes.tobytes()

        t0 = time.monotonic()
        await websocket.send_bytes(image_bytes)
        send_duration = time.monotonic() - t0

        # Track send times to detect backpressure
        send_times.append(send_duration)
        if len(send_times) > 30:
            send_times.pop(0)

        avg_send = sum(send_times) / len(send_times)
        # If average send time > 50ms, reduce quality
        if avg_send > 0.05 and quality > 20:
            quality -= 5
        elif avg_send < 0.02 and quality < 80:
            quality += 5

        await asyncio.sleep(1.0 / 15)
```
