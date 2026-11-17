# Networking Modes and ROS2 Implications

### Host Networking

```yaml
services:
  my_node:
    network_mode: host      # Shares host network namespace; DDS multicast works natively
```

### Bridge Networking (Default)

```yaml
services:
  my_node:
    networks: [ros_net]
networks:
  ros_net:
    driver: bridge          # DDS multicast blocked; requires unicast peer config
```

### Macvlan Networking

```yaml
networks:
  ros_macvlan:
    driver: macvlan
    driver_opts:
      parent: eth0
    ipam:
      config:
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.1
services:
  my_node:
    networks:
      ros_macvlan:
        ipv4_address: 192.168.1.50   # Real LAN IP; DDS multicast works natively
```

### Decision Table

| Factor | Host | Bridge | Macvlan |
|---------------------|------------------|-------------------------|-----------------------|
| DDS discovery | Works natively | Needs unicast peers | Works natively |
| Network isolation | None | Full isolation | LAN-level isolation |
| Port conflicts | Yes (host ports) | No (mapped ports) | No (unique IPs) |
| Performance | Native | Slight overhead | Near-native |
| Multi-host support | No | With overlay networks | Yes (same LAN) |
| When to use | Dev, single host | CI/CD, multi-tenant | Multi-robot on LAN |
