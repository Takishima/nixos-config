# ROS2 Parameter Management via REST

```python
# parameter_api.py — Full CRUD for ROS2 parameters via HTTP

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import Any
import asyncio

router = APIRouter(prefix="/api/params", tags=["parameters"])


class ParamUpdate(BaseModel):
    value: Any


@router.get("/")
async def list_parameters():
    """List all declared parameters on the bridge node."""
    ros_node = app.state.ros_node
    param_names = ros_node.get_parameters_by_prefix("")
    return {
        "parameters": [
            {"name": name, "value": param.value}
            for name, param in param_names.items()
        ]
    }


@router.get("/{name}")
async def get_param(name: str):
    """Get a single parameter value."""
    ros_node = app.state.ros_node
    try:
        param = ros_node.get_parameter(name)
        return {"name": name, "value": param.value, "type": str(param.type_)}
    except Exception:
        raise HTTPException(404, f"Parameter '{name}' not found")


@router.put("/{name}")
async def set_param(name: str, body: ParamUpdate):
    """Set a parameter value. Notifies WebSocket subscribers."""
    ros_node = app.state.ros_node
    try:
        old_value = ros_node.get_parameter(name).value
        ros_node.set_parameters([
            rclpy.parameter.Parameter(name, value=body.value)
        ])
        # Notify WebSocket subscribers of the change
        await param_broadcaster.notify(name, old_value, body.value)
        return {"name": name, "old_value": old_value, "new_value": body.value}
    except Exception as e:
        raise HTTPException(400, str(e))


# Parameter change notifications via WebSocket
class ParamBroadcaster:
    def __init__(self):
        self.subscribers: set[WebSocket] = set()

    async def notify(self, name: str, old_value: Any, new_value: Any):
        dead = set()
        for ws in self.subscribers.copy():
            try:
                await ws.send_json({
                    "type": "param_change",
                    "name": name,
                    "old_value": old_value,
                    "new_value": new_value,
                })
            except Exception:
                dead.add(ws)
        self.subscribers -= dead

    async def handle_ws(self, websocket: WebSocket):
        await websocket.accept()
        self.subscribers.add(websocket)
        try:
            while True:
                await websocket.receive_text()  # Keep alive
        except WebSocketDisconnect:
            self.subscribers.discard(websocket)


param_broadcaster = ParamBroadcaster()


@router.websocket("/ws")
async def param_ws(websocket: WebSocket):
    """WebSocket endpoint for real-time parameter change notifications."""
    await param_broadcaster.handle_ws(websocket)
```
