# Production Deployment Checklist

1. **Use lifecycle nodes** for all critical components
1. **Set `ROS_LOCALHOST_ONLY=1`** if not communicating across machines
1. **Pin your DDS implementation** (CycloneDDS recommended)
1. **Configure QoS explicitly** — never rely on defaults for production
1. **Set `ROS_DOMAIN_ID`** to isolate your robot from others on the network
1. **Enable ROS2 security** (SROS2) for authenticated communication
1. **Use composition** for nodes that exchange large data
1. **Record bags in MCAP format** — better tooling, random access, compression
1. **Set up launch-testing** for integration tests
1. **Use `ros2 doctor`** as part of your health check pipeline
