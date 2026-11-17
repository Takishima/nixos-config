# Production Perception Checklist

1. **Calibrate before deploying** — intrinsics, extrinsics, hand-eye
1. **Validate calibration** with independent measurements
1. **Set sensor exposure** appropriately — auto-exposure can cause detection flicker
1. **Undistort** before any geometric computation
1. **Filter depth** — remove flying pixels, fill small holes
1. **Timestamp at capture** — not at processing time
1. **Track objects** across frames — don't rely on single-frame detections
1. **Handle sensor failures** — missing frames, degraded depth, overexposure
1. **Log perception output** — bounding boxes, confidence scores, 3D positions
1. **Benchmark latency** — measure each pipeline stage, find bottlenecks
1. **Test with edge cases** — empty scenes, cluttered scenes, reflective surfaces, direct sunlight
1. **Version your models** — pin detection/segmentation model versions in deployment
