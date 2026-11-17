> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# Robotics security skill index

Pick the topic and read its reference before hardening a robot or reviewing a security control.

| Topic | When to read | Reference |
|---|---|---|
| Robot attack surface | mapping vectors and impacts (DDS, SSH, web, firmware, physical) | `references/attack-surface.md` |
| SROS2 DDS security | keystore generation, governance/permissions XML, certificate lifecycle | `references/sros2.md` |
| Network hardening | VLAN segmentation, firewall rules, ingress / egress policies | `references/network.md` |
| SSH and host hardening | sshd config, sudoers, no-root login, fail2ban, kernel hardening | `references/ssh.md` |
| Secrets management | secret stores (1Password, sops, Vault), avoid env-var leakage, rotation | `references/secrets.md` |
| Container security | rootless containers, image provenance, capability drops, seccomp | `references/containers.md` |
| Physical-cyber safety intersection | when a cyber incident becomes a kinetic safety problem; IEC 62443 mapping | `references/physical-safety.md` |
| Secure boot and firmware | UEFI / TPM / Secure Boot, signed initramfs, signed kernel modules | `references/boot.md` |
| Audit and monitoring | journald shipping, auditd rules, SIEM integration, anomaly detection | `references/audit.md` |
| Anti-patterns | what to avoid (telnet, plaintext DDS, baked secrets, shared keys) | `references/anti-patterns.md` |
| Robotics security checklist | gate items before fleet deployment | `references/checklist.md` |

## When to use this skill

- Hardening ROS 2 communications with SROS2
- Generating and managing certificates / keystores
- Network segmentation for robot fleets
- Hardening SSH and the host OS on a robot
- Managing secrets and credentials
- Threat-modelling the physical-cyber boundary

After reading the matching reference, follow its guidance for the task.
