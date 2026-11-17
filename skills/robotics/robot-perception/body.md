> Adapted from [arpitg1304/robotics-agent-skills](https://github.com/arpitg1304/robotics-agent-skills) (Apache-2.0).

# Robot perception skill index

Pick the topic and read its reference before building or reviewing a perception pipeline.

| Topic | When to read | Reference |
|---|---|---|
| Sensor landscape | choosing between RGB / RGBD / stereo / lidar / IMU; pros, cons, latency, cost | `references/sensors.md` |
| Camera models and calibration | pinhole/fisheye intrinsics, distortion, extrinsic, hand-eye calibration | `references/calibration.md` |
| Sensor streaming best practices | frame rates, drop policies, time stamping, hardware sync, soft sync | `references/streaming.md` |
| RGB processing pipelines | colour spaces, demosaicing, exposure control, object detection / segmentation | `references/rgb.md` |
| Depth processing | depth maps, sensor fusion of RGB + depth, hole filling, edge-aware filtering | `references/depth.md` |
| Point cloud processing | PCL / Open3D, downsampling, segmentation, ICP, plane / cluster extraction | `references/pointcloud.md` |
| Multi-sensor fusion | extrinsic calibration, EKF / UKF, factor graphs, sync strategies, soft real-time | `references/fusion.md` |
| Perception latency budget | end-to-end pipeline budgets, queue sizing, GPU pipelines, when to drop frames | `references/latency.md` |
| Anti-patterns | what to avoid (silent QoS mismatches, wall-clock sync, unbounded queues) | `references/anti-patterns.md` |
| Production checklist | gate items before shipping a perception pipeline | `references/checklist.md` |

## When to use this skill

- Calibrating cameras, LiDARs, or multi-sensor rigs
- Building RGB / depth / point-cloud pipelines
- Fusing sensors with EKF / UKF / factor graphs
- Hitting a latency budget for closed-loop control
- Time-synchronising sensors at hardware or software level

After reading the matching reference, follow its guidance for the task.
