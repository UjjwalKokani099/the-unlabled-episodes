class_name EventOnUse
extends Node3D
## Generic usable thing: on use fires Events `event_id`, optionally shows `message`, and
## (if `once`) stops being usable. Child: Interactable.

@export var event_id: StringName
@export var message: String = ""
@export var once: bool = true

@onready var _area: Interactable = $Interactable


func _ready() -> void:
	if once and event_id != &"" and Events.has_fired(event_id):
		_area.enabled = false
	_area.interacted.connect(func(_by: Node3D) -> void:
		Events.fire(event_id)
		if message != "":
			get_tree().call_group("hud", "show_message", message, 3.0)
		if once:
			_area.enabled = false)
