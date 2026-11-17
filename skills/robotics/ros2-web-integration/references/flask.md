# Pattern 3: Flask Bridge

### Flask with rclpy Threading

Flask is synchronous. Running rclpy.spin() on the same thread as Flask will block one or the other. The correct approach uses a background thread for the ROS2 executor.

```python
# BAD: Blocking — rclpy.spin() never returns, Flask never starts
import rclpy
from flask import Flask, jsonify

app = Flask(__name__)

def bad_main():
    rclpy.init()
    node = rclpy.create_node('flask_bridge')
    rclpy.spin(node)  # Blocks forever — Flask never starts
    app.run(host='0.0.0.0', port=8080)
```

```python
# GOOD: Threaded executor — rclpy spins in background, Flask serves in main thread
import threading
import rclpy
from rclpy.executors import MultiThreadedExecutor
from flask import Flask, jsonify

app = Flask(__name__)
ros_node = None

class SimpleRosNode(rclpy.node.Node):
    def __init__(self):
        super().__init__('flask_bridge')
        self._lock = threading.Lock()
        self._data = {}
        self.create_subscription(
            Odometry, '/odom', self._odom_cb,
            QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT, depth=1))

    def _odom_cb(self, msg):
        with self._lock:
            self._data['x'] = msg.pose.pose.position.x
            self._data['y'] = msg.pose.pose.position.y

    def get_data(self):
        with self._lock:
            return self._data.copy()

@app.route('/api/status')
def status():
    return jsonify(ros_node.get_data())

def main():
    global ros_node
    rclpy.init()
    ros_node = SimpleRosNode()

    executor = MultiThreadedExecutor()
    executor.add_node(ros_node)
    spin_thread = threading.Thread(target=executor.spin, daemon=True)
    spin_thread.start()

    try:
        app.run(host='0.0.0.0', port=8080, threaded=True)
    finally:
        executor.shutdown()
        ros_node.destroy_node()
        rclpy.shutdown()
```

### When Flask Is Enough vs When You Need FastAPI

Use **Flask** when:

- You only need simple REST endpoints (no WebSocket)
- The web bridge is an internal tool with few concurrent users
- Your team is already familiar with Flask and not ready to adopt async
- You do not need OpenAPI/Swagger documentation auto-generation

Use **FastAPI** when:

- You need WebSocket endpoints for real-time streaming
- You need high concurrency (async handlers, many simultaneous clients)
- You want automatic request validation via Pydantic models
- You want auto-generated OpenAPI docs for the robot API
- You are streaming video or sensor data to multiple clients
