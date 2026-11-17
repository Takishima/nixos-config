# Principle 10: Observe Everything — You Can't Debug What You Can't See

Every module should emit structured telemetry. When a robot behaves unexpectedly at 2 AM, logs are all you have.

```python
import structlog
from dataclasses import dataclass, asdict

logger = structlog.get_logger()

@dataclass
class PerceptionEvent:
    timestamp: float
    num_detections: int
    processing_time_ms: float
    frame_id: str
    detector_confidence: float

class PerceptionModule:
    def process(self, image):
        t_start = time.monotonic()
        detections = self.detector.detect(image)
        t_elapsed = (time.monotonic() - t_start) * 1000

        # Structured logging — machine-parseable
        event = PerceptionEvent(
            timestamp=time.time(),
            num_detections=len(detections),
            processing_time_ms=t_elapsed,
            frame_id=image.header.frame_id,
            detector_confidence=max(
                (d.confidence for d in detections), default=0.0),
        )
        logger.info("perception.processed", **asdict(event))

        # Performance warnings
        if t_elapsed > 100:
            logger.warning("perception.slow",
                processing_time_ms=t_elapsed,
                threshold_ms=100)

        # Anomaly detection
        if len(detections) == 0 and self._expected_objects > 0:
            logger.warning("perception.no_detections",
                expected=self._expected_objects,
                image_mean=float(image.data.mean()))

        return detections
```

**What to log**: state transitions, command executions, safety events, performance metrics, sensor health, error conditions, configuration changes.

**How to log**: structured key-value pairs (not printf strings), with timestamps, severity levels, and module identifiers.

______________________________________________________________________
