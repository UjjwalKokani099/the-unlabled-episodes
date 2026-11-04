class_name Door
extends Node3D
## Hinged door. Origin = floor level on the hinge side; the closed panel runs along +X.
## Swings away from whoever opens it (eased), with a hinge creak; closing ends in the latch
## clicking home. Locked doors rattle in their frame (sound + a small camera nudge) and show
## a message. Sounds are SoundSets (data/sounds/door_*.tres), never the same twice in a row.

signal opened
signal closed

const CREAK: SoundSet = preload("res://data/sounds/door_creak.tres")
const LATCH: SoundSet = preload("res://data/sounds/door_latch.tres")
const RATTLE: SoundSet = preload("res://data/sounds/door_rattle.tres")

@export var open_angle: float = 100.0
@export var open_duration: float = 0.7
@export var locked: bool = false
@export var locked_message: String = "It's locked."
@export var start_open: bool = false
## Events id that unlocks this door (e.g. an objective id like &"find_key").
@export var unlock_event: StringName
## Events id fired the first time the door opens (e.g. &"storage_opened").
@export var opened_event: StringName
## Played (from the door) when slam() actually bangs it shut.
@export var slam_sound: AudioStream

var is_open: bool = false
var _tween: Tween
var _slam_player: AudioStreamPlayer3D

## The hinge is the physics body itself: AnimatableBody3D only syncs its collision
## when its own transform changes, not when a parent moves.
@onready var hinge: AnimatableBody3D = $Hinge
@onready var interactable: Interactable = $Hinge/Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	interactable.default_tick = false  # the door has its own sounds
	if slam_sound:
		_slam_player = AudioStreamPlayer3D.new()
		_slam_player.stream = slam_sound
		_slam_player.bus = &"SFX"
		_slam_player.unit_size = 8.0
		_slam_player.position = Vector3(0.55, 1.1, 0.0)
		add_child(_slam_player)
	if unlock_event != &"":
		EventBus.fired.connect(_on_event)
		if EventBus.has_fired(unlock_event):
			unlock()
	if start_open:
		hinge.rotation.y = deg_to_rad(open_angle)
		is_open = true
	_update_prompt()


## Opens the door so it swings away from `from_position` (world space).
func open_away_from(from_position: Vector3) -> void:
	var side := 1.0 if to_local(from_position).z >= 0.0 else -1.0
	_swing(deg_to_rad(open_angle) * side)
	_sound(CREAK, -6.0)
	is_open = true
	_update_prompt()
	opened.emit()
	if opened_event != &"" and not EventBus.has_fired(opened_event):
		EventBus.fire(opened_event)


func close() -> void:
	_swing(0.0)
	_sound(CREAK, -9.0)
	# The latch clicks home as the panel arrives.
	_tween.tween_callback(_sound.bind(LATCH, -4.0))
	is_open = false
	_update_prompt()
	closed.emit()


## Bangs the door shut fast (a scare). Optionally locks it afterwards.
## Returns true if it was open (so callers can skip a slam sound otherwise).
func slam(lock_after: bool = false) -> bool:
	var was_open := is_open
	if was_open:
		if _slam_player:
			_slam_player.play()
		_new_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) \
			.tween_property(hinge, "rotation:y", 0.0, 0.18)
		is_open = false
		_update_prompt()
		closed.emit()
	if lock_after:
		locked = true
	return was_open


func lock() -> void:
	locked = true


func unlock() -> void:
	locked = false


func _on_event(id: StringName) -> void:
	if id == unlock_event:
		unlock()


func _on_interacted(by: Node3D) -> void:
	if locked:
		get_tree().call_group("hud", "show_message", locked_message)
		_rattle()
		_sound(RATTLE, -3.0)
		get_tree().call_group("camera_shake", "add_trauma", 0.12)
	elif is_open:
		close()
	else:
		open_away_from(by.global_position)


func _swing(angle: float) -> void:
	_new_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
		.tween_property(hinge, "rotation:y", angle, open_duration)


func _rattle() -> void:
	if _tween and _tween.is_running():
		return
	var base := hinge.rotation.y
	var tween := _new_tween()
	for i in 3:
		tween.tween_property(hinge, "rotation:y", base + 0.015, 0.04)
		tween.tween_property(hinge, "rotation:y", base, 0.04)


func _new_tween() -> Tween:
	if _tween:
		_tween.kill()
	# The panel is a physics body, so animate it on physics frames.
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	return _tween


## Plays a clip from `set` at the middle of the door panel.
func _sound(set: SoundSet, volume_db: float) -> void:
	AudioManager.play_set_at(set, hinge.global_transform * Vector3(0.55, 1.1, 0.0), volume_db, 3.0)


func _update_prompt() -> void:
	interactable.prompt = "Close" if is_open else "Open"
