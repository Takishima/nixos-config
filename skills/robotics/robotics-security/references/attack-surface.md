# The Robot Attack Surface

Robots are unique: cyber vulnerabilities become **physical** threats.

```
  NETWORK                    MIDDLEWARE                   APPLICATION
  ┌────────────────┐        ┌────────────────┐           ┌────────────────┐
  │ Open DDS ports │───────▶│ Unauthenticated│──────────▶│ Hardcoded      │
  │ (7400-7500)    │        │ /cmd_vel pub   │           │ credentials    │
  │ Unsegmented LAN│        │ No msg signing │           │ Unvalidated cmd│
  └────────────────┘        └────────────────┘           └────────────────┘
  PHYSICAL                   FIRMWARE                     SUPPLY CHAIN
  ┌────────────────┐        ┌────────────────┐           ┌────────────────┐
  │ USB/debug ports│───────▶│ Unsigned       │──────────▶│ Compromised    │
  │ Serial consoles│        │ firmware OTA   │           │ ROS packages   │
  │ Exposed SBCs   │        │ No secure boot │           │ Unverified imgs│
  └────────────────┘        └────────────────┘           └────────────────┘
```

| Vector | Impact |
|--------|--------|
| Unauthenticated `/cmd_vel` | Robot moves unexpectedly — injury/damage |
| Sensor spoofing (`/scan`, `/camera/image`) | Robot collides, wrong decisions |
| Open DDS multicast discovery | Full topic graph enumeration by passive listener |
| USB/serial physical access | Root shell, firmware flash, data exfiltration |
| Unsigned firmware update | Persistent backdoor in motor controllers |
