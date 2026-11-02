class_name FootstepsAbove
extends Area3D
## Presence before reveal: inside this area (a stairwell), someone one floor up walks when
## the player walks and stops when they stop. Each of the player's steps is answered a beat
## later from `height` metres above them. Give it a CollisionShape3D child.
## Only once `armed_by` has fired; stops for good after `max_steps` or above `stop_above_y`.

@export var armed_by: StringName
@export var height: float = 3.2
@export var delay: float = 0.2
@export var max_steps: int = 40
## Stops once the player climbs above this height (they've reached where the sound was).
@export var stop_above_y: float = 11.0
@export var volume_db: float = -2.0

const STEP := preload("res://assets/audio/sfx/step_concrete.wav")

var steps_answered: int = 0
var _player: Player
var _inside: bool = false
var _last_count: int = 0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = STEP
	_audio.volume_db = volume_db
	_audio.unit_size = 4.0
	_audio.bus = &"SFX"
	add_child(_audio)
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			_player = b
			_inside = true
			_last_count = _steps())
	body_exited.connect(func(b: Node3D) -> void:
		if b is Player:
			_inside = false)


func _physics_process(_delta: float) -> void:
	if not _inside or _player == null or steps_answered >= max_steps:
		return
	var count := _steps()
	# Steps taken before arming (or above the stop height) are never answered later.
	if (armed_by != &"" and not Events.has_fired(armed_by)) or _player.global_position.y > stop_above_y:
		_last_count = count
		return
	if count > _last_count:
		_last_count = count
		_answer()


func _answer() -> void:
	steps_answered += 1
	var at := _player.global_position + Vector3(randf_range(-0.6, 0.6), height, randf_range(-0.6, 0.6))
	await get_tree().create_timer(delay).timeout
	_audio.global_position = at
	_audio.pitch_scale = randf_range(0.85, 1.0)
	_audio.play()


func _steps() -> int:
	var feet := _player.get_node_or_null("Footsteps")
	return feet.steps_taken if feet else 0
