class_name Player
extends CharacterBody3D
## First-person player: walk / sprint / crouch, mouse look, flashlight.
##
## The node origin sits at the feet. The camera lives under Head, which moves down
## when crouching. The flashlight is "top level" (ignores its parent's transform) and
## chases the camera with a little lag, like a hand-held light.

signal flashlight_toggled(is_on: bool)

@export_group("Movement")
@export var walk_speed: float = 2.4
@export var sprint_speed: float = 4.2
@export var crouch_speed: float = 1.2
## Higher = reaches full speed faster.
@export var ground_accel: float = 12.0
## Higher = stops faster when you let go.
@export var ground_decel: float = 14.0
@export var air_accel: float = 2.0

@export_group("Body")
@export var stand_height: float = 1.75
@export var crouch_height: float = 1.0
## Eyes sit this far below the top of the head.
@export var eye_below_top: float = 0.12
## How fast the body shrinks/grows when crouching.
@export var crouch_blend: float = 10.0

@export_group("Camera")
@export var max_pitch: float = 85.0
## Head-bob radians per metre walked (sets step rhythm).
@export var bob_frequency: float = 4.5
@export var bob_amount: float = 0.035

@export_group("Flashlight")
@export var flashlight_on_start: bool = true
## Higher = flashlight follows the camera more tightly.
@export var flashlight_follow: float = 14.0
## Offset from the eyes (right, up, forward). Off-centre so shadows are visible.
@export var flashlight_offset: Vector3 = Vector3(0.18, -0.15, 0.0)

## Set false during cutscenes / menus to freeze movement and look.
var input_enabled: bool = true
var is_crouching: bool = false
var is_sprinting: bool = false

var _pitch: float = 0.0
var _height: float = 0.0
var _bob_time: float = 0.0
var _crouch_toggled: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interactor: Interactor = $Head/Camera3D/Interactor
@onready var flashlight: SpotLight3D = $Flashlight
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _shape: CapsuleShape3D = $CollisionShape3D.shape


func _ready() -> void:
	_height = stand_height
	_apply_height()
	camera.fov = Settings.fov
	Settings.changed.connect(_on_setting_changed)
	flashlight.top_level = true
	flashlight.global_transform = _flashlight_target()
	flashlight.visible = flashlight_on_start
	_set_mouse_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	# Esc is handled by the pause menu. If the mouse got freed some other way (alt-tab),
	# clicking in the game window grabs it again.
	if not _is_mouse_captured():
		if event is InputEventMouseButton and event.pressed:
			_set_mouse_captured(true)
			get_viewport().set_input_as_handled()
		return
	if not input_enabled:
		return

	if event is InputEventMouseMotion:
		# Touches also arrive as emulated mouse motion; touch look comes from TouchControls.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("crouch") and Settings.crouch_toggle:
		_crouch_toggled = not _crouch_toggled


func _physics_process(delta: float) -> void:
	var active := can_act()
	var move_input := Vector2.ZERO
	if active:
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if move_input != Vector2.ZERO and Engine.get_physics_frames() % 30 == 0:
			print("TOUCHDBG move_input=%s pos=%s vel=%s" % [move_input, global_position, velocity])  # TEMP

	_update_crouch(delta, active)

	var speed := walk_speed
	# Sprint only while moving forward and standing.
	is_sprinting = active and not is_crouching and move_input.y < -0.1 and Input.is_action_pressed("sprint")
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed

	if not is_on_floor():
		velocity += get_gravity() * delta

	var wish := transform.basis * Vector3(move_input.x, 0.0, move_input.y) * speed
	var rate := air_accel
	if is_on_floor():
		rate = ground_accel if move_input != Vector2.ZERO else ground_decel
	var blend := 1.0 - exp(-rate * delta)
	velocity.x = lerpf(velocity.x, wish.x, blend)
	velocity.z = lerpf(velocity.z, wish.z, blend)

	move_and_slide()
	_update_head_bob(delta)


func _process(delta: float) -> void:
	# Flashlight trails the camera slightly.
	var target := _flashlight_target()
	var blend := 1.0 - exp(-flashlight_follow * delta)
	var rot := flashlight.global_basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), blend)
	flashlight.global_transform = Transform3D(Basis(rot), target.origin)


## Puts the player at a spot (feet) facing the -Z of `facing` basis; resets look and speed.
func teleport(spot: Transform3D) -> void:
	global_position = spot.origin
	var forward := -spot.basis.z
	rotation.y = atan2(-forward.x, -forward.z)
	_pitch = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO


## True when the player is allowed to move, look and interact right now.
func can_act() -> bool:
	return input_enabled and _is_mouse_captured()


func toggle_flashlight() -> void:
	set_flashlight(not flashlight.visible)


func set_flashlight(on: bool) -> void:
	if flashlight.visible == on:
		return
	flashlight.visible = on
	flashlight_toggled.emit(on)


## Turns the view by `relative` pixels of mouse movement (TouchControls calls it too).
func look(relative: Vector2) -> void:
	_look(relative)


func _look(relative: Vector2) -> void:
	var sens := Settings.mouse_sensitivity
	rotate_y(deg_to_rad(-relative.x * sens))
	var dy := relative.y * (-1.0 if Settings.invert_y else 1.0)
	_pitch = clampf(_pitch - dy * sens, -max_pitch, max_pitch)
	head.rotation.x = deg_to_rad(_pitch)


func _update_crouch(delta: float, active: bool) -> void:
	var want := is_crouching
	if active:
		want = _crouch_toggled if Settings.crouch_toggle else Input.is_action_pressed("crouch")
	# Never stand up into a ceiling.
	if not want and _height < stand_height and not _has_headroom(stand_height - _height):
		want = true
	is_crouching = want

	var target := crouch_height if want else stand_height
	if is_equal_approx(_height, target):
		return
	var new_height := lerpf(_height, target, 1.0 - exp(-crouch_blend * delta))
	if absf(new_height - target) < 0.01:
		new_height = target
	_height = new_height
	_apply_height()


func _has_headroom(extra: float) -> bool:
	return not test_move(global_transform, Vector3.UP * extra)


func _apply_height() -> void:
	_shape.height = _height
	_collider.position.y = _height * 0.5
	head.position.y = _height - eye_below_top


func _update_head_bob(delta: float) -> void:
	var target := Vector3.ZERO
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if Settings.head_bob and is_on_floor() and ground_speed > 0.2:
		_bob_time += delta * ground_speed * bob_frequency
		target = Vector3(cos(_bob_time * 0.5) * bob_amount * 0.6, sin(_bob_time) * bob_amount, 0.0)
	camera.position = camera.position.lerp(target, 1.0 - exp(-10.0 * delta))


func _flashlight_target() -> Transform3D:
	var cam := camera.global_transform
	return Transform3D(cam.basis, cam.origin + cam.basis * flashlight_offset)


func _is_mouse_captured() -> bool:
	return Settings.mouse_captured()


func _set_mouse_captured(captured: bool) -> void:
	Settings.capture_mouse(captured)


func _on_setting_changed(key: StringName) -> void:
	match key:
		&"fov":
			camera.fov = Settings.fov
		&"crouch_toggle":
			_crouch_toggled = is_crouching
