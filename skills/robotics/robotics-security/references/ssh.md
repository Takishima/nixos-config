# SSH and Host Hardening

### SSH Key-Only Auth, Disable Root Login

```ini
# /etc/ssh/sshd_config
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers robot-admin
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no
```

```bash
sudo systemctl restart sshd
# Per-robot key pair (on management workstation)
ssh-keygen -t ed25519 -f ~/.ssh/robot_$(hostname) -C "admin@$(hostname)"
ssh-copy-id -i ~/.ssh/robot_$(hostname).pub -p 2222 robot-admin@10.10.30.5
```

### fail2ban for Robot Computers

```ini
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

```bash
sudo apt install fail2ban -y && sudo systemctl enable --now fail2ban
```

### Unattended Security Updates

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
# Key settings in /etc/apt/apt.conf.d/50unattended-upgrades:
#   Allowed-Origins: "${distro_id}:${distro_codename}-security"
#   Automatic-Reboot: "false"   # NEVER auto-reboot a running robot
```

### Minimal Installed Packages

```bash
# Remove unnecessary packages from robot computers
sudo apt purge -y avahi-daemon cups snapd modemmanager bluetooth bluez
sudo apt autoremove -y
```
