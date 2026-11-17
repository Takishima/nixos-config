# Perception Anti-Patterns

### 1. Processing Every Frame When You Don't Need To

```python
# ❌ BAD: Running heavy detection at sensor framerate
def callback(self, msg):
    detections = self.heavy_model(msg)  # 100ms on every 30Hz frame

# ✅ GOOD: Decimate or skip frames
def callback(self, msg):
    self.frame_count += 1
    if self.frame_count % 3 != 0:  # Process every 3rd frame
        return
    detections = self.heavy_model(msg)
```

### 2. Not Validating Depth Values

```python
# ❌ BAD: Using raw depth blindly
z = depth_image[v, u]
point_3d = backproject(u, v, z)  # z might be 0 (hole) or 65535 (invalid)

# ✅ GOOD: Always validate depth
z = depth_image[v, u]
if z <= 0 or z > max_range:
    return None
z_meters = z * depth_scale
```

### 3. Assuming Cameras Are Calibrated

```python
# ❌ BAD: Using default/nominal intrinsics
K = np.array([[600, 0, 320], [0, 600, 240], [0, 0, 1]])  # Guess

# ✅ GOOD: Load actual calibration
K = load_calibration("camera_serial_12345.yaml").camera_matrix
```

### 4. Ignoring Sensor Warmup

```python
# ❌ BAD: Using first frames from sensor
camera.start()
frame = camera.capture()  # Often overexposed, auto-exposure not settled

# ✅ GOOD: Discard initial frames
camera.start()
for _ in range(30):  # Let auto-exposure settle (~1 second at 30Hz)
    camera.capture()
frame = camera.capture()  # Now usable
```

### 5. Single-Pixel Depth Sampling

```python
# ❌ BAD: Single pixel is noisy and may be a hole
z = depth[int(center_y), int(center_x)]

# ✅ GOOD: Sample a neighborhood, use median
patch = depth[cy-3:cy+4, cx-3:cx+4]
valid = patch[patch > 0]
z = np.median(valid) if len(valid) > 0 else None
```

### 6. Not Handling Coordinate Frame Transforms

```python
# ❌ BAD: Assuming everything is in the same frame
object_position = detection.position  # In camera frame? Robot frame? World frame?
robot.move_to(object_position)        # Which frame does move_to expect?

# ✅ GOOD: Explicit frame tracking
object_in_camera = detection.position_3d       # Camera frame
object_in_base = T_base_camera @ np.append(object_in_camera, 1.0)  # Robot frame
robot.move_to(object_in_base[:3])
```
