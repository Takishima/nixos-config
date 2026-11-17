> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# ROS 2 web integration skill index

Pick the bridging pattern that matches the task and read its reference before writing a web↔ROS 2 integration.

> **Supported versions (as of 2026-05):** Humble (LTS), Jazzy (LTS, recommended), Kilted (latest non-LTS, EOL Dec 2026), Rolling. Iron is EOL.

| Topic | When to read | Reference |
|---|---|---|
| Architecture overview | choosing between rosbridge / FastAPI / Flask / WebRTC for a given workload | `references/architecture.md` |
| Pattern 1: rosbridge_suite | drop-in JSON-over-WebSocket bridge, paired with roslibjs in the browser | `references/rosbridge.md` |
| Pattern 2: FastAPI bridge | async REST + WebSocket bridge, custom protocol, fine-grained backpressure | `references/fastapi.md` |
| Pattern 3: Flask bridge | simpler synchronous REST bridge, easy MJPEG video, smaller dep footprint | `references/flask.md` |
| Video streaming | MJPEG over HTTP, WebRTC for low-latency camera feeds, GStreamer pipelines | `references/video-streaming.md` |
| Bidirectional communication | command channels, telemetry channels, reconnection, sequence numbers | `references/bidirectional.md` |
| Rate limiting and backpressure | downsampling sensor streams, websocket queue policies, dropping vs blocking | `references/rate-limiting.md` |
| Security | auth (token, JWT, mTLS), CORS, TLS termination, origin checks, abuse limits | `references/security.md` |
| ROS 2 parameter management via REST | exposing `ros2 param` as a REST endpoint, validation, hot-reload semantics | `references/parameters.md` |
| Anti-patterns | common pitfalls (blocking the executor, unbounded queues, leaking secrets) | `references/anti-patterns.md` |
| Production checklist | gate items before shipping a robot web interface | `references/checklist.md` |

## When to use this skill

- Building a web dashboard for robot operators
- Streaming camera feeds to a browser
- Exposing ROS 2 services as REST endpoints
- Implementing bidirectional WebSocket communication between a web UI and ROS 2 nodes
- Auth, CORS, and TLS for a robot-facing web interface
- Running async web frameworks alongside the ROS 2 executor

After reading the matching reference, follow its guidance for the task.
