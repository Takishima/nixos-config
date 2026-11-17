# Architecture Overview

### Comparison Table

| Feature | rosbridge_suite | Custom FastAPI Bridge | Custom Flask Bridge |
|---|---|---|---|
| Latency | ~5-15ms (WebSocket) | ~2-5ms (WebSocket), ~10-30ms (REST) | ~10-50ms (REST only without extensions) |
| Throughput | Medium (JSON serialization overhead) | High (binary WebSocket, async) | Low-Medium (sync, GIL-bound) |
| Auth | Basic (rosauth, limited) | Full (JWT, OAuth2, API keys) | Full (Flask-Login, JWT) |
| Complexity | Low (launch and connect) | Medium (must manage two event loops) | Medium (must manage threading) |
| Video Streaming | Requires separate web_video_server | Native (MJPEG, WebSocket binary) | MJPEG via generator responses |
| Production Ready | No (exposes full topic graph) | Yes | Yes (with gunicorn) |
| When to Use | Prototyping, foxglove, quick demos | Production APIs, high-perf streaming | Simple internal tools, legacy systems |

### When to Use rosbridge vs Custom Bridge

Use **rosbridge_suite** when:

- You need a working bridge in under 10 minutes
- The client is foxglove, webviz, or another rosbridge-aware tool
- Security is not a concern (local network, demo environment)
- You do not need custom business logic between web and ROS2

Use a **custom bridge** (FastAPI/Flask) when:

- You need authentication, authorization, or rate limiting
- You want to expose only specific topics/services (not the entire ROS2 graph)
- You need to transform or aggregate data before sending to the client
- You need REST endpoints for integration with non-WebSocket clients
- You are streaming video and need control over encoding and quality
- The system is deployed in production or on a public network
