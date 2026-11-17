# Pattern 8: Data Recording Architecture

**Critical for learning-based robotics** — designed for the ForgeIR ecosystem:

```
┌─────────────────────────────────────────────┐
│              Event-Based Recorder            │
│  Triggers: action boundaries, anomalies,     │
│  task completions, operator signals           │
├─────────────────────────────────────────────┤
│           Multimodal Data Streams            │
│  Camera (30Hz) | Joint State (100Hz) |       │
│  Force/Torque (1kHz) | Language Annotations  │
├─────────────────────────────────────────────┤
│            Storage Layer                     │
│  Episode-based structure with metadata       │
│  Format: MCAP / Zarr / HDF5 / RLDS          │
├─────────────────────────────────────────────┤
│           Quality Assessment                 │
│  Completeness checks, trajectory validation  │
│  Anomaly detection, diversity analysis       │
└─────────────────────────────────────────────┘
```

```python
class EpisodeRecorder:
    """Records robot episodes with event-based boundaries"""

    def __init__(self, config):
        self.streams = {}
        self.episode_active = False
        self.current_episode = None
        self.storage = StorageBackend(config['format'])  # Zarr, MCAP, etc.

    def register_stream(self, name, msg_type, frequency_hz):
        self.streams[name] = StreamConfig(
            name=name, type=msg_type, freq=frequency_hz)

    def start_episode(self, metadata: dict):
        """Begin recording an episode with metadata"""
        self.current_episode = Episode(
            id=uuid4(),
            start_time=time.monotonic(),
            metadata=metadata,  # task, operator, environment, etc.
            streams={name: [] for name in self.streams}
        )
        self.episode_active = True

    def record_step(self, stream_name, data, timestamp):
        if self.episode_active:
            self.current_episode.streams[stream_name].append(
                DataPoint(data=data, timestamp=timestamp))

    def end_episode(self, outcome: str, annotations: dict = None):
        """Finalize and store the episode"""
        self.episode_active = False
        self.current_episode.end_time = time.monotonic()
        self.current_episode.outcome = outcome
        self.current_episode.annotations = annotations

        # Validate before saving
        quality = self.validate_episode(self.current_episode)
        self.current_episode.quality_score = quality

        self.storage.save(self.current_episode)
        return self.current_episode.id
```
