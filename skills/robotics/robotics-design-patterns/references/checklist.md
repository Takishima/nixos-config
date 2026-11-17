# Architecture Decision Checklist

When designing a new robot system, answer these questions:

1. **What's the safety architecture?** (E-stop, watchdog, workspace limits)
1. **What are the real-time requirements?** (Control at 100Hz+, perception at 10-30Hz)
1. **What's the behavioral framework?** (BT for complex, FSM for simple)
1. **How does sim-to-real work?** (HAL pattern, same interfaces)
1. **How is data recorded?** (Episode-based, event-triggered, with metadata)
1. **How are failures handled?** (Graceful degradation, recovery behaviors)
1. **What's the communication middleware?** (ROS2 for most cases)
1. **How is the system deployed?** (Docker, snap, direct install)
1. **How is it tested?** (Unit, integration, hardware-in-the-loop, field)
1. **How is it monitored?** (Heartbeats, metrics, dashboards)
