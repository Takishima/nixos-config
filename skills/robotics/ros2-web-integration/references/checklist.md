# Web Integration Checklist

1. **Thread separation**: rclpy executor runs in a dedicated background thread; the web server runs in the main thread or its own thread. They never share an event loop.
1. **Shared state is lock-protected**: Every piece of data read by HTTP handlers and written by ROS2 callbacks is guarded by `threading.Lock()`. No bare attribute access across threads.
1. **Graceful shutdown coordination**: Signal handlers set a shutdown event, the executor is stopped before `rclpy.shutdown()`, and the spin thread is joined with a timeout.
1. **Topic allowlist enforced**: Only explicitly listed topics are exposed to web clients. The allowlist is loaded from a configuration file, not hardcoded.
1. **Rate limiting on all streams**: Every WebSocket stream has a per-client rate limiter (token bucket or time-based). Clients can request a lower rate but not exceed the server maximum.
1. **Command timeout watchdog**: Any endpoint that accepts velocity or motion commands publishes zero velocity if no command is received within 500ms, preventing runaway robots on disconnect.
1. **Video is compressed before transmission**: Camera feeds use `CompressedImage` topics or server-side JPEG encoding. Raw `Image` messages are never forwarded to web clients.
1. **TLS termination in front of the bridge**: An nginx or caddy reverse proxy handles TLS. The bridge itself listens on localhost only. WebSocket upgrade headers are properly proxied.
1. **Authentication on all mutation endpoints**: POST, PUT, DELETE endpoints and teleop WebSocket connections require a valid JWT or API key. Read-only status endpoints may be unauthenticated on private networks.
1. **CORS restricts origins**: `allow_origins` lists specific dashboard URLs. Wildcard `*` is never used in production.
1. **Connection lifecycle management**: WebSocket clients are tracked in a set, removed on disconnect, and periodically pruned. Dead client references are never retained.
1. **Binary WebSocket for high-bandwidth data**: Image frames, point clouds, and other binary data use `send_bytes()`, not base64-encoded JSON. This saves ~33% bandwidth and CPU on both sides.
