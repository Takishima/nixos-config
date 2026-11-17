# Network Hardening

### Network Segmentation

```
┌───────────────────┬──────────────────┬────────────────────────┐
│   CONTROL PLANE   │   DATA PLANE     │   MANAGEMENT PLANE     │
│   VLAN 10         │   VLAN 20        │   VLAN 30              │
│   10.10.10.0/24   │   10.10.20.0/24  │   10.10.30.0/24        │
├───────────────────┼──────────────────┼────────────────────────┤
│ /cmd_vel, /odom   │ /camera/image    │ SSH, Prometheus         │
│ /joint_states     │ /pointcloud      │ Log collection          │
│ /e_stop           │ /map, /rosbag    │ Fleet mgmt API          │
├───────────────────┼──────────────────┼────────────────────────┤
│ LOW LATENCY       │ HIGH BANDWIDTH   │ RESTRICTED ACCESS       │
│ QoS: RELIABLE     │ QoS: BEST_EFFORT │ Jump host / VPN + 2FA  │
└───────────────────┴──────────────────┴────────────────────────┘
```

Management plane is **never** reachable from data plane. Control plane traffic never transits WiFi.

### Firewall Rules for ROS2/DDS

```bash
#!/bin/bash
# firewall_ros2.sh — adapt interface names to your hardware
iptables -F && iptables -X

# Default: drop inbound, allow outbound
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT                                    # Loopback (intra-process DDS)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT      # Existing connections
iptables -A INPUT -p udp --dport 7400:7500 -s 10.10.10.0/24 -j ACCEPT  # DDS discovery — control VLAN
iptables -A INPUT -p udp --dport 7500:7700 -s 10.10.10.0/24 -j ACCEPT  # DDS user traffic
iptables -A INPUT -p tcp --dport 22 -s 10.10.30.0/24 -j ACCEPT         # SSH — mgmt VLAN only
iptables -A INPUT -i wlan0 -d 239.255.0.0/16 -j DROP                   # Block multicast on WiFi
iptables -A INPUT -j LOG --log-prefix "DROPPED: " --log-level 4
iptables -A INPUT -j DROP
iptables-save > /etc/iptables/rules.v4
```

### VLAN Configuration for Robot Networks

```yaml
# /etc/netplan/01-robot-vlans.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0: {dhcp4: false}
  vlans:
    vlan10:
      id: 10
      link: eth0
      addresses: [10.10.10.5/24]
    vlan20:
      id: 20
      link: eth0
      addresses: [10.10.20.5/24]
    vlan30:
      id: 30
      link: eth0
      addresses: [10.10.30.5/24]
      routes: [{to: default, via: 10.10.30.1}]
```

### Disabling DDS Multicast in Production

Multicast auto-discovery exposes the full topic graph. Use unicast peer lists.

```xml
<!-- cyclonedds_secure.xml -->
<CycloneDDS>
  <Domain>
    <General><AllowMulticast>false</AllowMulticast></General>
    <Discovery>
      <Peers>
        <Peer address="10.10.10.1"/>
        <Peer address="10.10.10.2"/>
        <Peer address="10.10.10.3"/>
      </Peers>
      <ParticipantIndex>auto</ParticipantIndex>
    </Discovery>
  </Domain>
</CycloneDDS>
```

```bash
export CYCLONEDDS_URI=file:///etc/ros2/cyclonedds_secure.xml
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
```

FastDDS equivalent — set `initialPeersList` with explicit unicast locators and omit multicast locators in the participant profile. Use `FASTRTPS_DEFAULT_PROFILES_FILE` env var to load.
