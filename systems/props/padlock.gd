class_name Padlock
extends Node3D
## Lock a door from here (terrace doors on the night round). Fires Events `event_id` once.
## Child: Interactable. `door` = the Door to lock.

@export var door: NodePath
@export var event_id: StringName = &"terrace_locked"

@onready var _area: Interactable = $Interactable


func _ready() -> void:
	var key := "lock:" + str(owner.get_path_to(self) if owner else get_path())
	if GameManager.get_flag(key, false):
		_done()
	_area.interacted.connect(func(_by: Node3D) -> void:
		var d := get_node_or_null(door) as Door
		if d and d.is_open:
			get_tree().call_group("hud", "show_message", "Close the door first.")
			return
		GameManager.set_flag(key)
		EventBus.fire(event_id)
		get_tree().call_group("hud", "show_message", "Padlocked.")
		_done())


func _done() -> void:
	var d := get_node_or_null(door) as Door
	if d:
		d.lock()
		d.locked_message = "Padlocked for the night."
	_area.enabled = false
