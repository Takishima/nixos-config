# Testing Anti-Patterns

### 1. Testing with `sleep()`

```python
# BAD: Flaky, slow, non-deterministic
def test_message_received():
    pub.publish(msg)
    time.sleep(2.0)  # Hope it arrives!
    assert received

# GOOD: Event-driven waiting with timeout
def test_message_received():
    pub.publish(msg)
    event = threading.Event()
    sub = create_sub(callback=lambda m: event.set())
    assert event.wait(timeout=5.0), "Message not received within timeout"
```

### 2. Not Testing Failure Cases

```python
# BAD: Only test the happy path

# GOOD: Test failures explicitly
def test_planner_unreachable_goal(self):
    """Planner should return None for unreachable goals"""
    result = planner.plan(start, unreachable_goal)
    assert result is None

def test_perception_no_objects(self):
    """Perception should return empty list when no objects visible"""
    empty_image = np.zeros((256, 256, 3), dtype=np.uint8)
    detections = perception.detect(empty_image)
    assert detections == []
```

### 3. Non-Deterministic Tests

```python
# BAD: Random seed changes between runs
trajectory = planner.plan(start, goal)  # Uses random sampling internally

# GOOD: Fix random seed for reproducibility
def test_rrt_planner(self):
    np.random.seed(42)
    trajectory = planner.plan(start, goal, seed=42)
    assert len(trajectory) > 0
```
