# Security

### TLS/HTTPS with Nginx Reverse Proxy

Never expose the robot web bridge directly to untrusted networks. Use nginx as a TLS-terminating reverse proxy.

```nginx
# /etc/nginx/sites-available/robot-bridge
server {
    listen 443 ssl;
    server_name robot.example.com;

    ssl_certificate /etc/ssl/certs/robot.pem;
    ssl_certificate_key /etc/ssl/private/robot.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    # REST API
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket endpoints
    location /ws/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;  # Keep WebSocket alive for 24h
    }

    # MJPEG video stream
    location /video/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_buffering off;  # Critical for streaming
        proxy_cache off;
    }
}
```

### Token-Based Auth (JWT)

```python
# auth.py — JWT authentication for FastAPI robot bridge
import time
from typing import Optional

from fastapi import Request, HTTPException, WebSocket
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt

SECRET_KEY = "load-from-environment-variable"  # Use os.environ in production
ALGORITHM = "HS256"
TOKEN_EXPIRY_S = 3600  # 1 hour


class RobotAPIAuth(HTTPBearer):
    """JWT bearer token authentication for robot API endpoints."""

    def __init__(self, auto_error: bool = True):
        super().__init__(auto_error=auto_error)

    async def __call__(self, request: Request) -> dict:
        credentials: HTTPAuthorizationCredentials = await super().__call__(request)
        if not credentials:
            raise HTTPException(status_code=403, detail="No credentials provided")
        return self._verify_token(credentials.credentials)

    @staticmethod
    def _verify_token(token: str) -> dict:
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            if payload.get("exp", 0) < time.time():
                raise HTTPException(status_code=401, detail="Token expired")
            return payload
        except jwt.InvalidTokenError:
            raise HTTPException(status_code=401, detail="Invalid token")


auth_scheme = RobotAPIAuth()


# Protect REST endpoints
@app.get("/api/robot/status", dependencies=[Depends(auth_scheme)])
async def protected_status():
    return {"status": "active"}


# Protect WebSocket endpoints — check token from query parameter
async def verify_ws_token(websocket: WebSocket) -> Optional[dict]:
    """WebSocket cannot use Authorization header — use query param."""
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4001, reason="Missing token")
        return None
    try:
        return RobotAPIAuth._verify_token(token)
    except HTTPException:
        await websocket.close(code=4003, reason="Invalid token")
        return None
```

### CORS Configuration

```python
# BAD: Allow all origins — any website can control your robot
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],        # Any website can send requests
    allow_methods=["*"],        # Including DELETE, PATCH
    allow_headers=["*"],
)

# GOOD: Explicit origins — only your dashboard can access the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://dashboard.example.com",
        "https://monitor.internal.example.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT"],
    allow_headers=["Authorization", "Content-Type"],
)
```

### Network Segmentation

Robots should run on isolated networks. The web bridge is the only component with interfaces on both the robot network and the user-facing network.

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Browser /      │     │   Web Bridge      │     │   ROS2 Nodes    │
│   Dashboard      │◄───►│   (FastAPI)        │◄───►│   (DDS network) │
│   (user network) │:443 │   eth0: user net   │     │   (robot VLAN)  │
│                  │     │   eth1: robot net  │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

- The web bridge has two network interfaces: one facing users (nginx TLS), one facing the robot DDS network.
- ROS2 DDS discovery is confined to the robot VLAN via `ROS_DOMAIN_ID` and DDS network interface configuration.
- The web bridge translates and filters — never forwards raw DDS traffic.
