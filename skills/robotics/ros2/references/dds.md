# DDS Configuration

### Choosing a DDS Implementation

```bash
# Set DDS middleware (in ~/.bashrc or launch)
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp    # Recommended for most cases
# export RMW_IMPLEMENTATION=rmw_fastrtps_cpp    # Default, good for multi-machine

# Limit DDS discovery to local machine (reduces network noise)
export ROS_LOCALHOST_ONLY=1

# Use ROS_DOMAIN_ID to isolate robot groups on same network
export ROS_DOMAIN_ID=42  # Range 0-101
```

### CycloneDDS Tuning (cyclonedds.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CycloneDDS xmlns="https://cdds.io/config">
  <Domain>
    <General>
      <NetworkInterfaceAddress>eth0</NetworkInterfaceAddress>
      <AllowMulticast>false</AllowMulticast>  <!-- Unicast for reliability -->
    </General>
    <Internal>
      <MaxMessageSize>65500</MaxMessageSize>
      <SocketReceiveBufferSize>10MB</SocketReceiveBufferSize>
    </Internal>
    <!-- For large data (images, point clouds) -->
    <Sizing>
      <ReceiveBufferSize>10MB</ReceiveBufferSize>
    </Sizing>
  </Domain>
</CycloneDDS>
```

```bash
export CYCLONEDDS_URI=file:///path/to/cyclonedds.xml
```
