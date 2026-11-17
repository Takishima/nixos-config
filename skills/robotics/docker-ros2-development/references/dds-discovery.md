# DDS Discovery Across Containers

### CycloneDDS XML Config for Unicast Across Containers

When containers use bridge networking (no multicast), configure explicit unicast peer lists.

```xml
<!-- cyclonedds.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<CycloneDDS xmlns="https://cdds.io/config">
  <Domain>
    <General>
      <Interfaces>
        <NetworkInterface autodetermine="true" priority="default"/>
      </Interfaces>
      <AllowMulticast>false</AllowMulticast>
    </General>
    <Discovery>
      <!-- Peer list uses docker-compose service names as hostnames -->
      <Peers>
        <Peer address="perception"/>
        <Peer address="navigation"/>
        <Peer address="driver"/>
        <Peer address="rosbridge"/>
      </Peers>
      <ParticipantIndex>auto</ParticipantIndex>
      <MaxAutoParticipantIndex>120</MaxAutoParticipantIndex>
    </Discovery>
    <Internal>
      <SocketReceiveBufferSize min="10MB"/>
    </Internal>
  </Domain>
</CycloneDDS>
```

### FastDDS XML Config

```xml
<!-- fastdds.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<dds xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
  <profiles>
    <participant profile_name="docker_participant" is_default_profile="true">
      <rtps>
        <builtin>
          <discovery_config>
            <discoveryProtocol>SIMPLE</discoveryProtocol>
            <leaseDuration><sec>10</sec></leaseDuration>
          </discovery_config>
          <initialPeersList>
            <locator>
              <udpv4><address>perception</address><port>7412</port></udpv4>
            </locator>
            <locator>
              <udpv4><address>navigation</address><port>7412</port></udpv4>
            </locator>
            <locator>
              <udpv4><address>driver</address><port>7412</port></udpv4>
            </locator>
          </initialPeersList>
        </builtin>
      </rtps>
    </participant>
  </profiles>
</dds>
```

Mount and activate in compose:

```yaml
# CycloneDDS
environment:
  - RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  - CYCLONEDDS_URI=file:///cyclonedds.xml
volumes:
  - ./config/cyclonedds.xml:/cyclonedds.xml:ro

# FastDDS
environment:
  - RMW_IMPLEMENTATION=rmw_fastrtps_cpp
  - FASTRTPS_DEFAULT_PROFILES_FILE=/fastdds.xml
volumes:
  - ./config/fastdds.xml:/fastdds.xml:ro
```

### Shared Memory Transport in Docker

DDS shared memory (zero-copy) requires `/dev/shm` sharing between containers. This provides highest throughput for large messages (images, point clouds).

```yaml
services:
  perception:
    shm_size: "512m"                    # Default 64 MB is too small for image topics
    volumes:
      - /dev/shm:/dev/shm              # Share host shm for inter-container zero-copy
```

```xml
<!-- Enable shared memory in CycloneDDS -->
<CycloneDDS xmlns="https://cdds.io/config">
  <Domain>
    <SharedMemory>
      <Enable>true</Enable>
    </SharedMemory>
  </Domain>
</CycloneDDS>
```

Constraints: all communicating containers must share `/dev/shm` or use `ipc: host`. Use `--ipc=shareable` on one container and `--ipc=container:<name>` on others for scoped sharing.
