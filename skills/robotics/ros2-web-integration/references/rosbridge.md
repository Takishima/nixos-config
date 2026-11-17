# Pattern 1: rosbridge_suite

### Installation and Launch

```bash
# Install rosbridge_suite
sudo apt install ros-${ROS_DISTRO}-rosbridge-suite

# Launch with default settings (port 9090)
ros2 launch rosbridge_server rosbridge_websocket_launch.xml

# Launch with custom port and SSL
ros2 launch rosbridge_server rosbridge_websocket_launch.xml \
    port:=9091 \
    ssl:=true \
    certfile:=/etc/ssl/certs/robot.pem \
    keyfile:=/etc/ssl/private/robot.key

# Launch with authentication (rosauth)
ros2 launch rosbridge_server rosbridge_websocket_launch.xml \
    authenticate:=true
```

### JavaScript Client (roslibjs)

```javascript
// Connect to rosbridge WebSocket
const ros = new ROSLIB.Ros({ url: 'ws://robot-host:9090' });

ros.on('connection', () => console.log('Connected to rosbridge'));
ros.on('error', (err) => console.error('Connection error:', err));
ros.on('close', () => console.log('Connection closed'));

// Subscribe to compressed camera images
const imageTopic = new ROSLIB.Topic({
  ros: ros,
  name: '/camera/image/compressed',
  messageType: 'sensor_msgs/msg/CompressedImage',
  // Throttle to 10 Hz to avoid flooding the browser
  throttle_rate: 100,
  // Queue size of 1 — drop stale frames
  queue_size: 1
});

imageTopic.subscribe((msg) => {
  // msg.data is base64-encoded JPEG
  const imgElement = document.getElementById('camera-feed');
  imgElement.src = 'data:image/jpeg;base64,' + msg.data;
});

// Call a ROS2 service
const getMapSrv = new ROSLIB.Service({
  ros: ros,
  name: '/map_server/map',
  serviceType: 'nav_msgs/srv/GetMap'
});

getMapSrv.callService(new ROSLIB.ServiceRequest({}), (result) => {
  console.log('Map received:', result.map.info.width, 'x', result.map.info.height);
}, (error) => {
  console.error('Service call failed:', error);
});

// Publish velocity commands from a virtual joystick
const cmdVelTopic = new ROSLIB.Topic({
  ros: ros,
  name: '/cmd_vel',
  messageType: 'geometry_msgs/msg/Twist'
});

function sendVelocity(linearX, angularZ) {
  const twist = new ROSLIB.Message({
    linear: { x: linearX, y: 0.0, z: 0.0 },
    angular: { x: 0.0, y: 0.0, z: angularZ }
  });
  cmdVelTopic.publish(twist);
}

// Publish at 10 Hz while joystick is active; stop on release
let joystickInterval = null;
function onJoystickMove(lx, az) {
  if (!joystickInterval) {
    joystickInterval = setInterval(() => sendVelocity(lx, az), 100);
  }
}
function onJoystickRelease() {
  clearInterval(joystickInterval);
  joystickInterval = null;
  sendVelocity(0.0, 0.0);  // Always send zero on release
}
```

### Limitations and Performance

- **JSON serialization overhead**: All messages are serialized to JSON, including binary data (base64-encoded). A 640x480 JPEG compressed image becomes ~30% larger over the wire.
- **No topic filtering**: By default rosbridge exposes every topic, service, and action on the ROS2 graph. Any connected client can publish to `/cmd_vel`.
- **Single-threaded event loop**: rosbridge_server uses a single Tornado event loop. High-frequency subscriptions from multiple clients can starve the loop.
- **No built-in rate limiting**: Clients can subscribe at any rate. A misbehaving client subscribing to a 30Hz point cloud will consume the server.
- **Authentication is minimal**: rosauth uses MAC-based tokens with shared secrets. It does not support JWT, OAuth2, or role-based access.
