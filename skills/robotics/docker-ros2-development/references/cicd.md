# CI/CD with Docker

### GitHub Actions Workflow

```yaml
# .github/workflows/ros2-docker-ci.yml
name: ROS2 Docker CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-test:
    runs-on: ubuntu-22.04
    strategy:
      fail-fast: false
      matrix:
        ros_distro: [humble, jazzy]
        include:
          - ros_distro: humble
            ubuntu: "22.04"
          - ros_distro: jazzy
            ubuntu: "24.04"
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Cache Docker layers
        uses: actions/cache@v4
        with:
          path: /tmp/.buildx-cache
          key: ${{ runner.os }}-buildx-${{ matrix.ros_distro }}-${{ hashFiles('src/**/package.xml') }}
          restore-keys: ${{ runner.os }}-buildx-${{ matrix.ros_distro }}-

      - name: Build and test
        run: |
          docker build --target dev \
            --build-arg ROS_DISTRO=${{ matrix.ros_distro }} \
            -t test-image:${{ matrix.ros_distro }} .
          docker run --rm test-image:${{ matrix.ros_distro }} bash -c '
            source /opt/ros/${{ matrix.ros_distro }}/setup.bash &&
            cd /ros2_ws &&
            colcon build --cmake-args -DBUILD_TESTING=ON &&
            colcon test --event-handlers console_direct+ &&
            colcon test-result --verbose'

      - name: Push runtime image
        if: github.ref == 'refs/heads/main'
        uses: docker/build-push-action@v5
        with:
          context: .
          target: runtime
          build-args: ROS_DISTRO=${{ matrix.ros_distro }}
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ matrix.ros_distro }}-latest
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ matrix.ros_distro }}-${{ github.sha }}
          push: true
          cache-from: type=local,src=/tmp/.buildx-cache
          cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max

      - name: Rotate cache
        run: rm -rf /tmp/.buildx-cache && mv /tmp/.buildx-cache-new /tmp/.buildx-cache
```

### Layer Caching

Order Dockerfile instructions from least-frequently-changed to most-frequently-changed:

```
1. Base image         (ros:humble-ros-base)     — changes on distro upgrade
2. System apt packages                           — changes on new dependency
3. rosdep install     (from package.xml)         — changes on new ROS dep
4. COPY src/ src/                                — changes on every code edit
5. colcon build                                  — rebuilds on source change
```

### Build Matrix Across Distros

```yaml
strategy:
  matrix:
    ros_distro: [humble, iron, jazzy, rolling]
    rmw: [rmw_cyclonedds_cpp, rmw_fastrtps_cpp]
    exclude:
      - ros_distro: iron           # Iron EOL — skip
        rmw: rmw_fastrtps_cpp
```
