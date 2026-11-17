# SROS2: DDS Security

SROS2 wraps DDS Security to provide authentication, encryption, and access control at the DDS layer.

### Keystore Generation and Certificate Setup

```bash
export ROS_SECURITY_KEYSTORE=~/sros2_keystore
ros2 security create_keystore ${ROS_SECURITY_KEYSTORE}

# Generate per-node enclaves (use exact fully-qualified node names)
ros2 security create_enclave ${ROS_SECURITY_KEYSTORE} /my_robot/camera_driver
ros2 security create_enclave ${ROS_SECURITY_KEYSTORE} /my_robot/navigation
ros2 security create_enclave ${ROS_SECURITY_KEYSTORE} /my_robot/motor_controller
ros2 security create_enclave ${ROS_SECURITY_KEYSTORE} /my_robot/teleop

# Result:
# sros2_keystore/
# ├── enclaves/my_robot/{camera_driver,navigation,...}/
# │   ├── cert.pem, key.pem          # Node identity
# │   ├── governance.p7s              # Signed governance
# │   └── permissions.p7s             # Signed permissions
# ├── public/ca.cert.pem              # CA certificate
# └── private/ca.key.pem              # CA private key — PROTECT THIS
```

### Security Policy XML

**Governance** — domain-wide security behavior:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<dds xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:noNamespaceSchemaLocation="omg_shared_ca_governance.xsd">
  <domain_access_rules>
    <domain_rule>
      <domains><id_range><min>0</min><max>230</max></id_range></domains>
      <allow_unauthenticated_participants>false</allow_unauthenticated_participants>
      <enable_join_access_control>true</enable_join_access_control>
      <discovery_protection_kind>ENCRYPT</discovery_protection_kind>
      <liveliness_protection_kind>ENCRYPT</liveliness_protection_kind>
      <rtps_protection_kind>ENCRYPT</rtps_protection_kind>
      <topic_access_rules>
        <topic_rule>
          <topic_expression>*</topic_expression>
          <enable_discovery_protection>true</enable_discovery_protection>
          <enable_read_access_control>true</enable_read_access_control>
          <enable_write_access_control>true</enable_write_access_control>
          <metadata_protection_kind>ENCRYPT</metadata_protection_kind>
          <data_protection_kind>ENCRYPT</data_protection_kind>
        </topic_rule>
      </topic_access_rules>
    </domain_rule>
  </domain_access_rules>
</dds>
```

**Permissions** — per-enclave publish/subscribe rules:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<dds xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:noNamespaceSchemaLocation="omg_shared_ca_permissions.xsd">
  <permissions>
    <grant name="/my_robot/motor_controller">
      <subject_name>CN=/my_robot/motor_controller</subject_name>
      <validity><not_before>2024-01-01T00:00:00</not_before>
                <not_after>2026-01-01T00:00:00</not_after></validity>
      <allow_rule>
        <domains><id>0</id></domains>
        <publish><topics><topic>rt/joint_states</topic></topics></publish>
        <subscribe><topics><topic>rt/cmd_vel</topic></topics></subscribe>
      </allow_rule>
      <default>DENY</default>
    </grant>
    <grant name="/my_robot/teleop">
      <subject_name>CN=/my_robot/teleop</subject_name>
      <validity><not_before>2024-01-01T00:00:00</not_before>
                <not_after>2026-01-01T00:00:00</not_after></validity>
      <allow_rule>
        <domains><id>0</id></domains>
        <publish><topics><topic>rt/cmd_vel</topic></topics></publish>
        <subscribe><topics><topic>rt/joy</topic></topics></subscribe>
      </allow_rule>
      <default>DENY</default>
    </grant>
  </permissions>
</dds>
```

### Enabling Security in Launch Files

```python
import os
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    security_env = {
        'ROS_SECURITY_KEYSTORE': os.path.expanduser('~/sros2_keystore'),
        'ROS_SECURITY_ENABLE': 'true',
        'ROS_SECURITY_STRATEGY': 'Enforce',  # Enforce=reject unauth, Permissive=warn only
    }
    return LaunchDescription([
        Node(package='my_robot_drivers', executable='motor_controller',
             name='motor_controller', namespace='my_robot',
             additional_env=security_env),
        Node(package='my_robot_nav', executable='navigation',
             name='navigation', namespace='my_robot',
             additional_env=security_env),
    ])
```

Always use `Enforce` in production. `Permissive` logs violations but allows them — debugging aid only.

### Per-Topic Access Control

Design with **least privilege**:

| Node | Publishes | Subscribes | Rationale |
|------|-----------|------------|-----------|
| `motor_controller` | `/joint_states` | `/cmd_vel` | Driver acts on velocity only |
| `navigation` | `/cmd_vel`, `/path` | `/scan`, `/odom`, `/map` | Nav reads sensors, writes commands |
| `camera_driver` | `/camera/image_raw` | (none) | Pure source — no subscriptions |
| `teleop` | `/cmd_vel` | `/joy` | Joystick passthrough — minimal surface |

A compromised `camera_driver` **cannot** publish to `/cmd_vel` — permissions deny it at the DDS layer.
