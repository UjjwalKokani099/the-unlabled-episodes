class_name CameraShake
extends Node
## Child of the player's Camera3D. Adds trauma-based shake (scares, slams) and a very
## subtle constant hand-held sway. Owns the camera's local rotation.
## Anyone can shake the camera: get_tree().call_group("camera_shake", "add_trauma", 0.5)

## Pitch / yaw / roll in degrees at full trauma.
@export var max_angles_deg: Vector3 = Vector3(2.5, 2.5, 3.5)
## Trauma lost per second (1.0 = full shake fades in one second).
@export var trauma_decay: float = 1.3
@export var shake_speed: float = 24.0
## Hand-held sway (off when Settings.head_bob is off).
@export var sway_angle_deg: float = 0.3
@export var sway_speed: float = 0.4

## 0..1. Shake strength is trauma squared, so small hits stay small.
var trauma: float = 0.0

var _noise := FastNoiseLite.new()
var _time: float = 0.0

@onready var _camera: Camera3D = get_parent()


func _ready() -> void:
	add_to_group("camera_shake")
	_noise.seed = randi()
	_noise.frequency = 1.0


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var shake := trauma * trauma
	var rot := Vector3.ZERO
	for axis in 3:
		rot[axis] = deg_to_rad(max_angles_deg[axis]) * shake * _noise.get_noise_2d(_time * shake_speed, axis * 100.0)
	if Settings.head_bob:
		for axis in 2:
			rot[axis] += deg_to_rad(sway_angle_deg) * _noise.get_noise_2d(_time * sway_speed, 500.0 + axis * 100.0)
	_camera.rotation = rot
