class_name Door
extends Node3D
## Hinged door. Origin = floor level on the hinge side; the closed panel runs along +X.
## Swings away from whoever opens it. Locked doors rattle and show a message.

signal opened
signal closed

@export var open_angle: float = 100.0
@export var open_duration: float = 0.7
@export var locked: bool = false
@export var locked_message: String = "It's locked."
@export var start_open: bool = false
## Events id that unlocks this door (e.g. an objective id like &"find_key").
@export var unlock_event: StringName
## Events id fired the first time the door opens (e.g. &"storage_opened").
@export var opened_event: StringName

var is_open: bool = false
var _tween: Tween

## The hinge is the physics body itself: AnimatableBody3D only syncs its collision
## when its own transform changes, not when a parent moves.
@onready var hinge: AnimatableBody3D = $Hinge
@onready var interactable: Interactable = $Hinge/Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	if unlock_event != &"":
		Events.fired.connect(_on_event)
		if Events.has_fired(unlock_event):
			unlock()
	if start_open:
		hinge.rotation.y = deg_to_rad(open_angle)
		is_open = true
	_update_prompt()


## Opens the door so it swings away from `from_position` (world space).
func open_away_from(from_position: Vector3) -> void:
	var side := 1.0 if to_local(from_position).z >= 0.0 else -1.0
	_swing(deg_to_rad(open_angle) * side)
	is_open = true
	_update_prompt()
	opened.emit()
	if opened_event != &"" and not Events.has_fired(opened_event):
		Events.fire(opened_event)


func close() -> void:
	_swing(0.0)
	is_open = false
	_update_prompt()
	closed.emit()


func unlock() -> void:
	locked = false


func _on_event(id: StringName) -> void:
	if id == unlock_event:
		unlock()


func _on_interacted(by: Node3D) -> void:
	if locked:
		get_tree().call_group("hud", "show_message", locked_message)
		_rattle()
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


func _update_prompt() -> void:
	interactable.prompt = "Close" if is_open else "Open"
