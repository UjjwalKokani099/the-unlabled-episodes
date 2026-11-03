class_name Drawer
extends AnimatableBody3D
## A drawer that slides out along its local +Z (the front faces +Z). Whatever is a child of
## it (notes, Pickups, Inspectables) rides along. The drawer is the physics body itself:
## AnimatableBody3D only syncs collision when its own transform changes.
## Child: Interactable (on the front panel). Locked drawers rattle; `unlock_event` opens
## the lock. Stays open/closed across checkpoints (Game flag).

signal opened
signal closed

@export var open_distance: float = 0.32
@export var duration: float = 0.35
@export var locked: bool = false
@export var locked_message: String = "Locked."
## Events id that unlocks it (e.g. &"desk_key").
@export var unlock_event: StringName
## Events id fired the first time it opens.
@export var opened_event: StringName

const SLIDE := preload("res://assets/audio/sfx/drawer_slide.wav")

var is_open: bool = false
var _closed_position: Vector3
var _tween: Tween
var _sound: AudioStreamPlayer3D

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	_closed_position = position
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = SLIDE
	_sound.bus = &"SFX"
	_sound.unit_size = 3.0
	add_child(_sound)
	interactable.interacted.connect(func(_by: Node3D) -> void: toggle())
	if unlock_event != &"":
		if EventBus.has_fired(unlock_event):
			locked = false
		EventBus.fired.connect(func(id: StringName) -> void:
			if id == unlock_event:
				locked = false
				_update_prompt())
	if GameManager.get_flag(_flag_key(), false):
		is_open = true
		position = _open_position()
	_update_prompt()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	if locked:
		_rattle()
		get_tree().call_group("hud", "show_message", locked_message)
		return
	is_open = true
	_slide(_open_position())
	GameManager.set_flag(_flag_key())
	opened.emit()
	if opened_event != &"" and not EventBus.has_fired(opened_event):
		EventBus.fire(opened_event)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_slide(_closed_position)
	GameManager.set_flag(_flag_key(), false)
	closed.emit()


func _open_position() -> Vector3:
	return _closed_position + transform.basis.z.normalized() * open_distance


func _slide(target: Vector3) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target, duration)
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()
	_update_prompt()


func _rattle() -> void:
	if _tween:
		_tween.kill()
	var out := _closed_position + transform.basis.z.normalized() * 0.012
	_tween = create_tween()
	for i in 2:
		_tween.tween_property(self, "position", out, 0.04)
		_tween.tween_property(self, "position", _closed_position, 0.05)


func _update_prompt() -> void:
	interactable.prompt = "Close drawer" if is_open else "Open drawer"


func _flag_key() -> String:
	return "drawer:" + str(owner.get_path_to(self) if owner else get_path())
