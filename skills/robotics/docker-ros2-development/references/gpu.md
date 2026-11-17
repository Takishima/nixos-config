# GPU Passthrough for Perception

### NVIDIA Container Toolkit Setup

```bash
# Install NVIDIA Container Toolkit on the host
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Compose Config with deploy.resources

```yaml
services:
  perception:
    image: my_robot_perception:latest
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1                    # Number of GPUs (or "all")
              capabilities: [gpu]
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility,video
    shm_size: "1g"                        # Large shm for GPU<->CPU transfers
```

For Dockerfiles that need CUDA, start from NVIDIA base and install ROS2 on top:

```dockerfile
FROM nvidia/cuda:12.2.0-cudnn8-runtime-ubuntu22.04 AS perception-base
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
       -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) \
       signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
       http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
       > /etc/apt/sources.list.d/ros2.list \
    && apt-get update && apt-get install -y --no-install-recommends \
       ros-humble-ros-base ros-humble-cv-bridge ros-humble-image-transport \
    && rm -rf /var/lib/apt/lists/*
```

### Verification

```bash
docker compose exec perception bash -c '
  nvidia-smi
  python3 -c "import torch; print(f\"CUDA available: {torch.cuda.is_available()}\")"
'
```
