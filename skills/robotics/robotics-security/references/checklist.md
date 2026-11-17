# Robotics Security Checklist

1. **SROS2 enabled with `Enforce` strategy** — all nodes use encrypted, authenticated DDS
1. **Per-node enclaves with least-privilege permissions** — each node publishes/subscribes only to required topics
1. **Network segmented into control/data/management VLANs** — firewall rules between zones
1. **DDS multicast disabled** — unicast peer lists only, no auto-discovery on LAN
1. **SSH hardened** — key-only auth, non-default port, fail2ban, no root login
1. **No hardcoded credentials** — secrets from environment files with 640 permissions
1. **Certificates rotated on schedule** — automated monthly rotation, explicit validity periods
1. **Containers run as non-root** — USER directive, no-new-privileges, all capabilities dropped
1. **E-stop is hardware-independent** — hardwired circuit works with all software/network down
1. **Safety controller on separate hardware** — velocity/workspace limits enforced outside main compute
1. **Command velocity validated at driver level** — clamping, rate limiting, watchdog to zero
1. **auditd monitoring active** — keystore access, config changes, USB events, root commands logged
1. **Firmware updates signature-verified** — no unsigned code on motor controllers or safety MCUs
1. **Security tested in CI/CD** — SROS2 Enforce in integration tests, image scanning in pipeline
