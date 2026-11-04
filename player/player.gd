class_name Player
extends CharacterBody3D
## First-person player: walk / sprint / crouch, mouse look, flashlight.
##
## The node origin sits at the feet. The camera lives under Head, which moves down
## when crouching. The flashlight is "top level" (ignores its parent's transform) and
## chases the camera with a little lag, like a hand-held light.

signal flashlight_toggled(is_on: bool)

@export_group("Movement")
@export var walk_speed: float = 2.2
@export var sprint_speed: float = 3.8
## Crouching and careful walking.
@export var crouch_speed: float = 1.2
## Seconds to reach full speed / to come to a stop (eased, never instant).
@export var accel_time: float = 0.2
@export var decel_time: float = 0.15
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
## Head bob height in metres at walking speed. Its rhythm comes from the footsteps (one
## dip per footfall), so it always matches the step sounds.
@export var bob_amount: float = 0.032
## Extra field of view while sprinting (degrees), eased in and out.
@export var sprint_fov_kick: float = 4.0

@export_group("Flashlight")
@export var flashlight_on_start: bool = true
## Higher = flashlight follows the camera more tightly.
@export var flashlight_follow: float = 14.0
## Offset from the eyes (right, up, forward). Off-centre so shadows are visible.
@export var flashlight_offset: Vector3 = Vector3(0.18, -0.15, 0.0)

## Set false during cutscenes / menus to freeze movement and look.
var input_enabled: bool = true
## The phone in Nikhil's hand (PlayerPhone.attach), or null: tapes before 2009 have none.
var phone: PlayerPhone = null
var is_crouching: bool = false
var is_sprinting: bool = false

var _pitch: float = 0.0
var _height: float = 0.0
var _crouch_toggled: bool = false
var _sprint_toggled: bool = false
var _last_floor_y: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _land_dip: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interactor: Interactor = $Head/Camera3D/Interactor
@onready var flashlight: SpotLight3D = $Flashlight
@onready var footsteps: Footsteps = $Footsteps
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _shape: CapsuleShape3D = $CollisionShape3D.shape


func _ready() -> void:
	_height = stand_height
	_apply_height()
	camera.fov = SettingsManager.fov
	SettingsManager.changed.connect(_on_setting_changed)
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
		# Touches also arrive as mouse motion (emulated, and from the browser): in touch mode
		# the view only turns via TouchControls.
		if event.device != InputEvent.DEVICE_ID_EMULATION and not InputManager.touch_mode:
			_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("crouch") and SettingsManager.crouch_toggle:
		_crouch_toggled = not _crouch_toggled
	elif event.is_action_pressed("sprint") and SettingsManager.sprint_toggle:
		_sprint_toggled = not _sprint_toggled


func _physics_process(delta: float) -> void:
	var active := can_act()
	var move_input := Vector2.ZERO
	if active:
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	_update_crouch(delta, active)

	var speed := walk_speed
	# Run only while moving forward, standing, and where the chapter allows it.
	var want_run := _sprint_toggled if SettingsManager.sprint_toggle else Input.is_action_pressed("sprint")
	is_sprinting = active and running_allowed() and not is_crouching and move_input.y < -0.1 and want_run \
		and not is_using_phone()
	if SettingsManager.sprint_toggle and move_input.y >= -0.1:
		_sprint_toggled = false  # stopping ends a toggled run
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed

	if not is_on_floor():
		velocity += get_gravity() * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)

	var wish := transform.basis * Vector3(move_input.x, 0.0, move_input.y) * speed
	# Exponential easing: ~95% of the target speed after accel_time / decel_time.
	var rate := air_accel
	if is_on_floor():
		rate = 3.0 / (accel_time if move_input != Vector2.ZERO else decel_time)
	var blend := 1.0 - exp(-rate * delta)
	velocity.x = lerpf(velocity.x, wish.x, blend)
	velocity.z = lerpf(velocity.z, wish.z, blend)

	move_and_slide()
	# Landing: the knees take it (a short dip, deeper for longer falls).
	if is_on_floor() and not _was_on_floor and _fall_speed > 1.5:
		_land_dip = -clampf(_fall_speed * 0.018, 0.02, 0.14)
		get_tree().call_group("camera_shake", "add_trauma", clampf(_fall_speed * 0.03, 0.0, 0.3))
	# Stepping down a stair or a kerb: a small dip, like the knee bending.
	if is_on_floor() and _was_on_floor:
		var drop := _last_floor_y - global_position.y
		if drop > 0.04:
			_land_dip -= minf(drop * 0.35, 0.05)
	if is_on_floor():
		_fall_speed = 0.0
		_last_floor_y = global_position.y
	_was_on_floor = is_on_floor()
	_update_head_bob(delta)


func _process(delta: float) -> void:
	# Gamepad right stick (eased curve: fine aim near the centre).
	if can_act():
		var stick := InputManager.pad_look()
		if stick != Vector2.ZERO:
			_turn(stick * stick.length() * InputManager.PAD_LOOK_SPEED * SettingsManager.controller_sensitivity * delta)
	# Flashlight trails the camera slightly.
	var target := _flashlight_target()
	var blend := 1.0 - exp(-flashlight_follow * delta)
	var rot := flashlight.global_basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), blend)
	flashlight.global_transform = Transform3D(Basis(rot), target.origin)
	# Sprint widens the view a little (eased; the base value is the player's setting).
	var want_fov := SettingsManager.fov + (sprint_fov_kick if is_sprinting and SettingsManager.sway_allowed() else 0.0)
	camera.fov = lerpf(camera.fov, want_fov, 1.0 - exp(-6.0 * delta))


## Puts the player at a spot (feet) facing the -Z of `facing` basis; resets look and speed.
func teleport(spot: Transform3D) -> void:
	global_position = spot.origin
	var forward := -spot.basis.z
	rotation.y = atan2(-forward.x, -forward.z)
	_pitch = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO


## True while the phone is up (no running, no using the world).
func is_using_phone() -> bool:
	return phone != null and phone.is_raised()


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
	_turn(relative * SettingsManager.mouse_sensitivity)


## Turns the view by `degrees` (x = yaw to the right, y = pitch down), honouring invert Y.
func _turn(degrees: Vector2) -> void:
	rotate_y(deg_to_rad(-degrees.x))
	var dy := degrees.y * (-1.0 if SettingsManager.invert_y else 1.0)
	_pitch = clampf(_pitch - dy, -max_pitch, max_pitch)
	head.rotation.x = deg_to_rad(_pitch)


func _update_crouch(delta: float, active: bool) -> void:
	var want := is_crouching
	if active:
		want = _crouch_toggled if SettingsManager.crouch_toggle else Input.is_action_pressed("crouch")
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
	if is_on_floor() and ground_speed > 0.2:
		# Locked to the footsteps: lowest point when a foot lands (phase 0), highest
		# between steps, a little sideways sway towards the stepping foot.
		var amount := bob_amount * SettingsManager.motion_scale() * clampf(ground_speed / walk_speed, 0.4, 1.5)
		var phase := footsteps.phase()
		var down := (1.0 + cos(phase * TAU)) * 0.5
		var side := sin(phase * PI) * (1.0 if footsteps.left_foot else -1.0)
		target = Vector3(side * amount * 0.5, (0.5 - down) * amount, 0.0)
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-7.0 * delta))
	target.y += _land_dip * maxf(SettingsManager.motion_scale(), 0.3)
	camera.position = camera.position.lerp(target, 1.0 - exp(-14.0 * delta))


## False in chapters that don't allow running (ChapterData.allow_running).
func running_allowed() -> bool:
	var chapter := GameManager.current_chapter
	return chapter == null or chapter.allow_running


func _flashlight_target() -> Transform3D:
	var cam := camera.global_transform
	return Transform3D(cam.basis, cam.origin + cam.basis * flashlight_offset)


func _is_mouse_captured() -> bool:
	return InputManager.mouse_captured()


func _set_mouse_captured(captured: bool) -> void:
	InputManager.capture_mouse(captured)


func _on_setting_changed(key: StringName) -> void:
	match key:
		&"fov":
			camera.fov = SettingsManager.fov
		&"crouch_toggle":
			_crouch_toggled = is_crouching
