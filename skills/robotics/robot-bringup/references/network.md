# Network Configuration for Multi-Machine ROS2

### Static IP Configuration

Assign a static IP to the robot's wired interface using netplan (Ubuntu 22.04+).

```yaml
# /etc/netplan/01-robot-network.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 10.0.0.10/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
  wifis:
    wlan0:
      dhcp4: true
      access-points:
        "RobotNetwork":
          password: "securepassword"
```

```bash
# Apply netplan configuration
sudo netplan apply
```

### DDS Discovery Across Machines

CycloneDDS requires explicit peer configuration for multi-machine setups since multicast may not work across network segments.

```xml
<!-- /etc/robot/cyclonedds.xml -->
<CycloneDDS>
  <Domain>
    <General>
      <Interfaces>
        <NetworkInterface name="eth0" priority="default" multicast="false"/>
      </Interfaces>
      <AllowMulticast>false</AllowMulticast>
    </General>
    <Discovery>
      <ParticipantIndex>auto</ParticipantIndex>
      <Peers>
        <!-- Robot onboard computer -->
        <Peer address="10.0.0.10"/>
        <!-- Base station / operator workstation -->
        <Peer address="10.0.0.20"/>
        <!-- Second robot (if applicable) -->
        <Peer address="10.0.0.11"/>
      </Peers>
      <MaxAutoParticipantIndex>30</MaxAutoParticipantIndex>
    </Discovery>
    <Internal>
      <SocketReceiveBufferSize min="10MB"/>
    </Internal>
  </Domain>
</CycloneDDS>
```

### Firewall Rules

DDS uses a range of UDP ports for discovery and data exchange. Open these ports on both the robot and the base station.

```bash
#!/bin/bash
# /usr/local/bin/robot-firewall-setup.sh
# Open firewall ports for CycloneDDS discovery and data exchange.

# DDS discovery (SPDP) uses UDP port 7400 + (250 * domain_id) + participant_id
# For domain_id=42: base port = 7400 + 250*42 = 17900
DOMAIN_ID=42
BASE_PORT=$((7400 + 250 * DOMAIN_ID))

# Allow discovery (SPDP) multicast/unicast
sudo ufw allow proto udp from 10.0.0.0/24 to any port $BASE_PORT:$((BASE_PORT + 100))

# Allow data exchange (SEDP) user traffic ports
DATA_PORT=$((BASE_PORT + 1))
sudo ufw allow proto udp from 10.0.0.0/24 to any port $DATA_PORT:$((DATA_PORT + 200))

# Allow all traffic on the robot subnet (simpler alternative)
# sudo ufw allow from 10.0.0.0/24

sudo ufw reload
echo "Firewall configured for ROS2 DDS on domain $DOMAIN_ID"
```

### ROS_DOMAIN_ID and ROS_LOCALHOST_ONLY

```bash
# Isolate robots on the same network by domain ID (0-232)
export ROS_DOMAIN_ID=42

# Lock DDS traffic to localhost only (useful for single-machine development)
export ROS_LOCALHOST_ONLY=1

# For multi-machine setups, ensure ROS_LOCALHOST_ONLY is 0 on all machines
export ROS_LOCALHOST_ONLY=0

# Verify DDS discovery across machines
ros2 daemon stop && ros2 daemon start
ros2 topic list  # Should see topics from both machines
```
