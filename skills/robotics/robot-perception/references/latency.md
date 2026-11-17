# Perception Latency Budget

```
Component                   Typical Latency    Budget Target
───────────────────────────────────────────────────────────────
Sensor capture              1-10 ms            —
Image transfer (USB3)       2-5 ms             —
Undistortion                1-2 ms             < 3 ms
Detection (GPU)             10-50 ms           < 30 ms
Detection (CPU)             50-500 ms          < 100 ms
Depth processing            2-5 ms             < 5 ms
Point cloud generation      3-10 ms            < 10 ms
Segmentation (GPU)          15-40 ms           < 30 ms
Tracking update             0.5-2 ms           < 2 ms
3D pose estimation          5-20 ms            < 15 ms
───────────────────────────────────────────────────────────────
TOTAL PIPELINE              ~50-150 ms         < 100 ms target

For 10 Hz perception: budget = 100 ms per frame
For 30 Hz perception: budget = 33 ms per frame

RULE: Perception latency + planning latency < control period
      If control runs at 100 Hz (10 ms), perception must be
      pipelined — process frame N while control uses frame N-1.
```
