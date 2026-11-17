# Principle 4: Interface Segregation — Small, Focused Interfaces

Don't force modules to depend on interfaces they don't use. Many small interfaces beat one large one.

**Why it matters in robotics**: A simple 1-DOF gripper shouldn't implement a 6-DOF dexterous hand interface. A fixed camera shouldn't implement pan-tilt methods.

```python
# ❌ BAD: Fat interface — every camera must implement ALL of these
class CameraInterface(ABC):
    @abstractmethod
    def capture_rgb(self) -> np.ndarray: ...
    @abstractmethod
    def capture_depth(self) -> np.ndarray: ...
    @abstractmethod
    def capture_pointcloud(self) -> np.ndarray: ...
    @abstractmethod
    def set_exposure(self, value: float): ...
    @abstractmethod
    def set_pan_tilt(self, pan: float, tilt: float): ...
    @abstractmethod
    def stream_video(self) -> Iterator[np.ndarray]: ...
    # A simple USB webcam can't do half of these!

# ✅ GOOD: Segregated interfaces — implement only what you support
class RGBCamera(ABC):
    """Any camera that produces RGB images"""
    @abstractmethod
    def capture_rgb(self) -> np.ndarray: ...

    @property
    @abstractmethod
    def resolution(self) -> tuple: ...

class DepthCamera(ABC):
    """Cameras that also produce depth"""
    @abstractmethod
    def capture_depth(self) -> np.ndarray: ...

    @abstractmethod
    def get_depth_intrinsics(self) -> DepthIntrinsics: ...

class ControllableCamera(ABC):
    """Cameras with adjustable settings"""
    @abstractmethod
    def set_exposure(self, value: float): ...

    @abstractmethod
    def set_white_balance(self, value: float): ...

class PTZCamera(ABC):
    """Pan-tilt-zoom cameras"""
    @abstractmethod
    def set_pan_tilt(self, pan: float, tilt: float): ...

    @abstractmethod
    def set_zoom(self, level: float): ...


# A RealSense implements RGB + Depth, but not PTZ
class RealSenseD435(RGBCamera, DepthCamera, ControllableCamera):
    def capture_rgb(self): ...
    def capture_depth(self): ...
    def set_exposure(self, value): ...
    # No PTZ methods — it's not a PTZ camera!

# A webcam implements only RGB
class USBWebcam(RGBCamera):
    def capture_rgb(self): ...
    # Nothing else required

# Perception code that only needs RGB doesn't pull in depth dependencies
class ObjectDetector:
    def __init__(self, camera: RGBCamera):  # Only needs RGB
        self.camera = camera

    def detect(self) -> List[Detection]:
        image = self.camera.capture_rgb()
        return self.model.predict(image)
```

______________________________________________________________________
