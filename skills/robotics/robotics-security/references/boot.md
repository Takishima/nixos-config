# Secure Boot and Firmware

### Read-Only Root Filesystem with Overlay

```bash
# /etc/fstab
/dev/mmcblk0p2  /        ext4  ro,noatime,errors=remount-ro  0 1
tmpfs           /tmp     tmpfs nosuid,nodev,size=128M         0 0
tmpfs           /var/log tmpfs nosuid,nodev,size=128M         0 0
/dev/mmcblk0p3  /data    ext4  rw,noatime,nosuid,nodev       0 2
```

```bash
# Alternative: overlayroot — all writes go to tmpfs, lost on reboot
sudo apt install overlayroot -y
# /etc/overlayroot.conf → overlayroot="tmpfs:swap=1"
```

### Signed Container Images

```bash
#!/bin/bash
set -euo pipefail
IMAGE="registry.myrobot.io/robot/navigation"
TAG="v$(cat VERSION)-$(git rev-parse --short HEAD)"
docker build -t "${IMAGE}:${TAG}" -f Dockerfile.prod .
trivy image --exit-code 1 --severity CRITICAL "${IMAGE}:${TAG}"
docker push "${IMAGE}:${TAG}"
cosign sign --key env://COSIGN_PRIVATE_KEY "${IMAGE}:${TAG}"
syft "${IMAGE}:${TAG}" -o spdx-json > sbom.json
cosign attach sbom --sbom sbom.json "${IMAGE}:${TAG}"
```

### TPM-Based Disk Encryption

```bash
# LUKS + TPM2 for unattended encrypted boot
sudo cryptsetup luksFormat /dev/mmcblk0p3
sudo cryptsetup luksOpen /dev/mmcblk0p3 robot-data
sudo systemd-cryptenroll /dev/mmcblk0p3 --tpm2-device=auto --tpm2-pcrs=0+7
# Disk decrypts only on original hardware with unmodified firmware
```

### Firmware Update Verification

```python
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
import subprocess

def verify_and_flash(firmware: Path, signature: Path, pubkey_path: Path):
    pubkey = serialization.load_pem_public_key(pubkey_path.read_bytes())
    try:
        pubkey.verify(signature.read_bytes(), firmware.read_bytes(),
                      ec.ECDSA(hashes.SHA256()))
    except Exception:
        raise SecurityError("Firmware signature verification FAILED — aborting")
    subprocess.run(['flash-tool', '--write', str(firmware)], check=True)
```
