# CI/CD Pipeline for Robotics

```yaml
# .github/workflows/robotics_ci.yml
name: Robotics CI

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-22.04
    container:
      image: ros:humble-ros-base
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          apt-get update
          rosdep install --from-paths src --ignore-src -y
          pip install pytest hypothesis numpy

      - name: Build
        run: |
          source /opt/ros/humble/setup.bash
          colcon build --packages-select my_pkg
          source install/setup.bash

      - name: Unit tests
        run: |
          source install/setup.bash
          colcon test --packages-select my_pkg
          colcon test-result --verbose

  integration-tests:
    runs-on: ubuntu-22.04
    container:
      image: ros:humble-ros-base
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4

      - name: Build full workspace
        run: |
          source /opt/ros/humble/setup.bash
          colcon build

      - name: Integration tests
        run: |
          source install/setup.bash
          launch_test src/my_pkg/test/test_integration.py

  simulation-tests:
    runs-on: ubuntu-22.04
    needs: integration-tests
    steps:
      - uses: actions/checkout@v4

      - name: Setup MuJoCo
        run: pip install mujoco

      - name: Simulation tests
        run: pytest tests/simulation/ -v --timeout=120
```
