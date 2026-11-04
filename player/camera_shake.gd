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
## Hand-held sway and breathing (SettingsManager.camera_sway; off with reduce_camera_motion).
@export var sway_angle_deg: float = 0.3
@export var sway_speed: float = 0.4
## Camera rolls into strafes, like a body shifting its weight (degrees at walking speed).
@export var strafe_roll_deg: float = 1.5
## Slow breathing rise and fall while standing still (degrees of pitch).
@export var breath_deg: float = 0.22
@export var breath_rate: float = 0.23

## 0..1. Shake strength is trauma squared, so small hits stay small.
var trauma: float = 0.0

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _roll: float = 0.0
var _body: CharacterBody3D

@onready var _camera: Camera3D = get_parent()


func _ready() -> void:
	add_to_group("camera_shake")
	_noise.seed = randi()
	_noise.frequency = 1.0
	# The player body (Camera3D -> Head -> Player), if this camera belongs to one.
	_body = _camera.get_parent().get_parent() as CharacterBody3D


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	# Reduce camera motion: shakes keep their meaning but at 40%.
	var shake := trauma * trauma * (0.4 if SettingsManager.reduce_camera_motion else 1.0)
	var rot := Vector3.ZERO
	for axis in 3:
		rot[axis] = deg_to_rad(max_angles_deg[axis]) * shake * _noise.get_noise_2d(_time * shake_speed, axis * 100.0)
	var lateral := 0.0
	var speed := 0.0
	if _body:
		var v := _body.velocity
		lateral = v.dot(_body.global_basis.x)
		speed = Vector2(v.x, v.z).length()
	# Strafe tilt (1-2 degrees, like shifting weight); off with reduced camera motion.
	var roll_target := -lateral / 2.2 * deg_to_rad(strafe_roll_deg) if not SettingsManager.reduce_camera_motion else 0.0
	_roll = lerpf(_roll, roll_target, 1.0 - exp(-6.0 * delta))
	rot.z += _roll
	if SettingsManager.sway_allowed():
		for axis in 2:
			rot[axis] += deg_to_rad(sway_angle_deg) * _noise.get_noise_2d(_time * sway_speed, 500.0 + axis * 100.0)
		# Breathing fades out while walking (the head bob takes over).
		rot.x += deg_to_rad(breath_deg) * sin(_time * TAU * breath_rate) * clampf(1.0 - speed, 0.0, 1.0)
	_camera.rotation = rot
