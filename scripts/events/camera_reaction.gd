class_name CameraReaction
extends EventReaction
## Shakes the camera and/or glitches the VHS picture.

## Trauma added to the camera (0..1; 0.3 = bump, 0.7 = slam, 1 = huge).
@export_range(0.0, 1.0) var shake: float = 0.0
## VHS distortion spike (0..1).
@export_range(0.0, 1.0) var glitch: float = 0.0
@export var glitch_duration: float = 0.5


func _react() -> void:
	if shake > 0.0:
		get_tree().call_group("camera_shake", "add_trauma", shake)
	if glitch > 0.0:
		get_tree().call_group("camcorder", "glitch", glitch, glitch_duration)
