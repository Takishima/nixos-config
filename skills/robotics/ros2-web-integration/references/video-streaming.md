# Video Streaming Patterns

### MJPEG Streaming

MJPEG streams work in `<img>` tags natively with no JavaScript needed. Useful for simple dashboards.

```python
# mjpeg_stream.py — MJPEG streaming endpoint for FastAPI
import cv2
import time
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from .ros_node import RobotBridgeNode


def generate_mjpeg(ros_node: RobotBridgeNode, max_fps: int = 15):
    """Generator that yields MJPEG frames as multipart HTTP response chunks."""
    min_interval = 1.0 / max_fps
    last_send = 0.0

    while True:
        now = time.monotonic()
        if now - last_send < min_interval:
            time.sleep(min_interval - (now - last_send))
            continue

        image_bytes = ros_node.get_latest_image()
        if image_bytes is None:
            time.sleep(0.05)
            continue

        last_send = time.monotonic()
        # Yield as multipart MJPEG frame
        yield (
            b'--frame\r\n'
            b'Content-Type: image/jpeg\r\n'
            b'Content-Length: ' + str(len(image_bytes)).encode() + b'\r\n'
            b'\r\n' + image_bytes + b'\r\n'
        )


@app.get("/video/mjpeg")
async def mjpeg_feed():
    ros_node: RobotBridgeNode = app.state.ros_node
    return StreamingResponse(
        generate_mjpeg(ros_node, max_fps=15),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )
```

Browser usage — no JavaScript required:

```html
<img src="http://robot-host:8080/video/mjpeg" alt="Robot Camera" />
```

### WebRTC via webrtc_ros

For low-latency, high-quality video streaming, use the `webrtc_ros` package.

```yaml
# webrtc_ros launch config
# webrtc_bridge.launch.py
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package='webrtc_ros',
            executable='webrtc_ros_server_node',
            name='webrtc_server',
            parameters=[{
                'port': 8443,
                'image_transport': 'compressed',
                # Bind to all interfaces for remote access
                'address': '0.0.0.0',
            }],
            remappings=[
                ('image', '/camera/image_raw'),
            ],
        ),
    ])
```

### Compressed Topic Streaming via WebSocket

For a balance between simplicity and performance, stream compressed image topics over a binary WebSocket.

```python
# Binary WebSocket streaming — more efficient than base64 JSON
@app.websocket("/ws/camera/binary")
async def camera_stream_binary(websocket: WebSocket):
    """Stream JPEG frames as binary WebSocket messages.

    ~30% more bandwidth-efficient than base64 JSON encoding.
    Client must handle raw binary blobs.
    """
    await websocket.accept()
    ros_node: RobotBridgeNode = websocket.app.state.ros_node
    min_interval = 1.0 / 15  # 15 FPS max

    try:
        last_bytes = None
        while True:
            image_bytes = ros_node.get_latest_image()
            if image_bytes is not None and image_bytes is not last_bytes:
                last_bytes = image_bytes
                await websocket.send_bytes(image_bytes)
            await asyncio.sleep(min_interval)
    except WebSocketDisconnect:
        pass
```

Client-side JavaScript:

```javascript
const ws = new WebSocket('ws://robot-host:8080/ws/camera/binary');
ws.binaryType = 'arraybuffer';

ws.onmessage = (event) => {
  const blob = new Blob([event.data], { type: 'image/jpeg' });
  const url = URL.createObjectURL(blob);
  const img = document.getElementById('camera-feed');
  // Revoke previous URL to prevent memory leaks
  if (img.src.startsWith('blob:')) URL.revokeObjectURL(img.src);
  img.src = url;
};
```
