# Bidirectional Communication

### Web UI to Robot Commands

```python
# teleop_handler.py — WebSocket teleop with command timeout watchdog
import asyncio
import time
from fastapi import WebSocket, WebSocketDisconnect

from .ros_node import RobotBridgeNode


class TeleopHandler:
    """Handles joystick input from browser with safety watchdog.

    If no command is received for 500ms, publishes zero velocity
    to prevent the robot from running away on disconnect.
    """

    COMMAND_TIMEOUT_S = 0.5  # Zero velocity after 500ms silence

    def __init__(self, ros_node: RobotBridgeNode):
        self.ros_node = ros_node
        self.last_command_time = 0.0

    async def handle(self, websocket: WebSocket):
        await websocket.accept()
        self.last_command_time = time.monotonic()

        # Start watchdog task
        watchdog_task = asyncio.create_task(self._watchdog())

        try:
            while True:
                data = await websocket.receive_json()
                # Expected: {"linear_x": 0.5, "angular_z": -0.3}
                linear_x = float(data.get("linear_x", 0.0))
                angular_z = float(data.get("angular_z", 0.0))

                # Clamp values for safety
                linear_x = max(-1.0, min(1.0, linear_x))
                angular_z = max(-2.0, min(2.0, angular_z))

                self.ros_node.publish_cmd_vel(linear_x, angular_z)
                self.last_command_time = time.monotonic()

                # Acknowledge to client
                await websocket.send_json({"ack": True, "t": self.last_command_time})
        except WebSocketDisconnect:
            pass
        finally:
            watchdog_task.cancel()
            # Always send zero on disconnect
            self.ros_node.publish_cmd_vel(0.0, 0.0)

    async def _watchdog(self):
        """Publish zero velocity if no command received within timeout."""
        while True:
            await asyncio.sleep(0.1)
            if time.monotonic() - self.last_command_time > self.COMMAND_TIMEOUT_S:
                self.ros_node.publish_cmd_vel(0.0, 0.0)
```

### Robot Status to Web UI

```python
# Status broadcast — push robot state to all connected WebSocket clients
class StatusBroadcaster:
    """Broadcasts robot status to all connected WebSocket clients."""

    def __init__(self, ros_node: RobotBridgeNode):
        self.ros_node = ros_node
        self.clients: set[WebSocket] = set()

    async def register(self, websocket: WebSocket):
        await websocket.accept()
        self.clients.add(websocket)
        try:
            # Keep connection alive — client sends pings
            while True:
                await websocket.receive_text()
        except WebSocketDisconnect:
            self.clients.discard(websocket)

    async def broadcast_loop(self, interval: float = 0.1):
        """Call this as a background task on app startup."""
        while True:
            odom = self.ros_node.get_latest_odom()
            if odom and self.clients:
                dead_clients = set()
                for client in self.clients.copy():
                    try:
                        await client.send_json({"type": "status", "odom": odom})
                    except Exception:
                        dead_clients.add(client)
                self.clients -= dead_clients
            await asyncio.sleep(interval)
```

### Command Acknowledgment Pattern

For reliable command execution, use a request-response pattern over WebSocket with correlation IDs.

```python
# Client sends:  {"id": "cmd-001", "action": "navigate_to", "x": 1.0, "y": 2.0}
# Server responds: {"id": "cmd-001", "status": "accepted", "estimated_time": 12.5}
# Server updates: {"id": "cmd-001", "status": "in_progress", "progress": 0.45}
# Server completes: {"id": "cmd-001", "status": "completed", "result": "success"}

@app.websocket("/ws/commands")
async def command_channel(websocket: WebSocket):
    await websocket.accept()
    ros_node: RobotBridgeNode = websocket.app.state.ros_node

    while True:
        try:
            data = await websocket.receive_json()
            cmd_id = data.get("id", "unknown")
            action = data.get("action")

            if action == "navigate_to":
                await websocket.send_json({
                    "id": cmd_id, "status": "accepted"
                })
                # Dispatch to ROS2 action client (non-blocking)
                asyncio.create_task(
                    execute_navigation(ros_node, websocket, cmd_id,
                                       data["x"], data["y"])
                )
            else:
                await websocket.send_json({
                    "id": cmd_id, "status": "error",
                    "message": f"Unknown action: {action}"
                })
        except WebSocketDisconnect:
            break
```
