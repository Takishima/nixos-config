# Pattern 2: Custom FastAPI Bridge

### Project Structure

```
robot_web_bridge/
├── robot_web_bridge/
│   ├── __init__.py
│   ├── ros_node.py          # ROS2 node with shared state
│   ├── web_app.py           # FastAPI application
│   ├── main.py              # Entry point: starts both rclpy and uvicorn
│   ├── auth.py              # JWT authentication middleware
│   └── rate_limiter.py      # Token bucket rate limiter
├── config/
│   └── bridge_config.yaml   # Allowed topics, rate limits, auth keys
├── launch/
│   └── web_bridge.launch.py
├── package.xml
├── setup.py
└── setup.cfg
```

### ROS2 Node with Async Executor

```python
# ros_node.py
import threading
import time
from typing import Optional

import rclpy
from rclpy.node import Node
from rclpy.executors import MultiThreadedExecutor
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from sensor_msgs.msg import CompressedImage
from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry
from std_srvs.srv import Trigger


class RobotBridgeNode(Node):
    """ROS2 node that exposes topic data via thread-safe shared state."""

    def __init__(self):
        super().__init__('web_bridge_node')

        # Thread-safe shared state for latest messages
        self._lock = threading.Lock()
        self._latest_image: Optional[bytes] = None
        self._latest_odom: Optional[dict] = None
        self._image_timestamp: float = 0.0

        # QoS for sensor data — best effort, keep last 1
        sensor_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            history=HistoryPolicy.KEEP_LAST,
            depth=1
        )

        # Subscribers
        self.create_subscription(
            CompressedImage, '/camera/image/compressed',
            self._image_cb, sensor_qos)
        self.create_subscription(
            Odometry, '/odom', self._odom_cb, sensor_qos)

        # Publisher for velocity commands
        self.cmd_vel_pub = self.create_publisher(Twist, '/cmd_vel', 10)

        # Service client for emergency stop
        self.estop_client = self.create_client(Trigger, '/emergency_stop')

        self.get_logger().info('Web bridge node initialized')

    def _image_cb(self, msg: CompressedImage):
        with self._lock:
            self._latest_image = bytes(msg.data)
            self._image_timestamp = time.monotonic()

    def _odom_cb(self, msg: Odometry):
        with self._lock:
            self._latest_odom = {
                'x': msg.pose.pose.position.x,
                'y': msg.pose.pose.position.y,
                'theta': 2.0 * __import__('math').atan2(
                    msg.pose.pose.orientation.z,
                    msg.pose.pose.orientation.w),
                'linear_vel': msg.twist.twist.linear.x,
                'angular_vel': msg.twist.twist.angular.z,
            }

    def get_latest_image(self) -> Optional[bytes]:
        with self._lock:
            return self._latest_image

    def get_latest_odom(self) -> Optional[dict]:
        with self._lock:
            return self._latest_odom.copy() if self._latest_odom else None

    def publish_cmd_vel(self, linear_x: float, angular_z: float):
        msg = Twist()
        msg.linear.x = float(linear_x)
        msg.angular.z = float(angular_z)
        self.cmd_vel_pub.publish(msg)
```

### FastAPI App with ROS2 Integration

```python
# web_app.py
import base64
import asyncio
import time
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .ros_node import RobotBridgeNode


class CmdVelRequest(BaseModel):
    linear_x: float = Field(ge=-1.0, le=1.0, description="Linear velocity m/s")
    angular_z: float = Field(ge=-2.0, le=2.0, description="Angular velocity rad/s")


def create_app(ros_node: RobotBridgeNode) -> FastAPI:
    app = FastAPI(title="Robot Web Bridge", version="1.0.0")

    # CORS — restrict to known origins in production
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["https://dashboard.example.com"],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT"],
        allow_headers=["Authorization", "Content-Type"],
    )

    # Store ros_node in app state so endpoints can access it
    app.state.ros_node = ros_node

    return app
```

### WebSocket Endpoint for Streaming

```python
# Add to web_app.py — WebSocket camera streaming endpoint

@app.websocket("/ws/camera")
async def camera_stream(websocket: WebSocket):
    """Stream compressed camera images as base64 over WebSocket.

    Supports per-client rate limiting via query parameter:
        ws://host/ws/camera?max_fps=10
    """
    await websocket.accept()
    ros_node: RobotBridgeNode = websocket.app.state.ros_node

    # Per-client rate limiting
    max_fps = int(websocket.query_params.get("max_fps", "15"))
    min_interval = 1.0 / max(1, min(max_fps, 30))  # Clamp 1-30 FPS
    last_send_time = 0.0
    last_image_bytes: Optional[bytes] = None

    try:
        while True:
            now = time.monotonic()
            elapsed = now - last_send_time

            if elapsed < min_interval:
                await asyncio.sleep(min_interval - elapsed)
                continue

            image_bytes = ros_node.get_latest_image()
            if image_bytes is None or image_bytes is last_image_bytes:
                # No new image available — avoid sending duplicates
                await asyncio.sleep(0.01)
                continue

            last_image_bytes = image_bytes
            last_send_time = time.monotonic()

            # Send as base64 JSON for browser compatibility
            b64_data = base64.b64encode(image_bytes).decode('ascii')
            await websocket.send_json({
                "type": "image",
                "format": "jpeg",
                "data": b64_data,
                "timestamp": last_send_time,
            })
    except WebSocketDisconnect:
        pass  # Client disconnected — clean exit
    except Exception as e:
        ros_node.get_logger().warn(f'WebSocket error: {e}')
    finally:
        # Graceful disconnect — no cleanup needed for read-only stream
        try:
            await websocket.close()
        except RuntimeError:
            pass  # Already closed
```

### REST Endpoints Wrapping ROS2 Services

```python
# Add to web_app.py — REST endpoints

@app.get("/api/robot/status")
async def get_robot_status():
    """Return current robot odometry and system status."""
    ros_node: RobotBridgeNode = app.state.ros_node
    odom = ros_node.get_latest_odom()
    if odom is None:
        raise HTTPException(status_code=503, detail="No odometry data available yet")
    return {
        "status": "active",
        "odometry": odom,
        "timestamp": time.time(),
    }


@app.post("/api/robot/cmd_vel")
async def post_cmd_vel(cmd: CmdVelRequest):
    """Send a velocity command to the robot."""
    ros_node: RobotBridgeNode = app.state.ros_node
    ros_node.publish_cmd_vel(cmd.linear_x, cmd.angular_z)
    return {"status": "ok", "linear_x": cmd.linear_x, "angular_z": cmd.angular_z}


@app.get("/api/robot/params/{param_name}")
async def get_parameter(param_name: str):
    """Read a ROS2 parameter from the bridge node."""
    ros_node: RobotBridgeNode = app.state.ros_node
    try:
        param = ros_node.get_parameter(param_name)
        return {"name": param_name, "value": param.value}
    except rclpy.exceptions.ParameterNotDeclaredException:
        raise HTTPException(status_code=404, detail=f"Parameter '{param_name}' not declared")


@app.put("/api/robot/params/{param_name}")
async def set_parameter(param_name: str, value: dict):
    """Set a ROS2 parameter on the bridge node.

    Body: {"value": <new_value>}
    """
    ros_node: RobotBridgeNode = app.state.ros_node
    try:
        param_value = value.get("value")
        if param_value is None:
            raise HTTPException(status_code=400, detail="Missing 'value' field")
        ros_node.set_parameters([rclpy.Parameter(param_name, value=param_value)])
        return {"name": param_name, "value": param_value, "status": "updated"}
    except rclpy.exceptions.ParameterNotDeclaredException:
        raise HTTPException(status_code=404, detail=f"Parameter '{param_name}' not declared")


@app.post("/api/robot/emergency_stop")
async def emergency_stop():
    """Call the emergency stop service."""
    ros_node: RobotBridgeNode = app.state.ros_node
    if not ros_node.estop_client.service_is_ready():
        raise HTTPException(status_code=503, detail="Emergency stop service not available")
    future = ros_node.estop_client.call_async(Trigger.Request())
    # Wait for result with timeout — run in executor to avoid blocking
    result = await asyncio.get_event_loop().run_in_executor(
        None, lambda: future.result(timeout=5.0)
    )
    return {"success": result.success, "message": result.message}
```

### Running FastAPI + rclpy Together

This is the critical integration point. Uvicorn runs in the main thread, rclpy spins in a background thread, and shutdown is coordinated via signals.

```python
# main.py
import signal
import sys
import threading

import rclpy
from rclpy.executors import MultiThreadedExecutor
import uvicorn

from .ros_node import RobotBridgeNode
from .web_app import create_app


def main():
    rclpy.init()
    ros_node = RobotBridgeNode()
    app = create_app(ros_node)

    # Spin rclpy in a background thread with a multi-threaded executor
    executor = MultiThreadedExecutor(num_threads=2)
    executor.add_node(ros_node)
    spin_thread = threading.Thread(target=executor.spin, daemon=True)
    spin_thread.start()

    # Shutdown coordination
    shutdown_event = threading.Event()

    def shutdown_handler(signum, frame):
        ros_node.get_logger().info('Shutdown signal received')
        shutdown_event.set()
        # Stop uvicorn by raising KeyboardInterrupt in main thread
        raise KeyboardInterrupt

    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    try:
        # Run uvicorn in the main thread
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8080,
            log_level="info",
            # Do NOT use reload in production with rclpy
            reload=False,
        )
    except KeyboardInterrupt:
        pass
    finally:
        ros_node.get_logger().info('Shutting down web bridge...')
        executor.shutdown()
        ros_node.destroy_node()
        rclpy.shutdown()
        spin_thread.join(timeout=5.0)


if __name__ == '__main__':
    main()
```
