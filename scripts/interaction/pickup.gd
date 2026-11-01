class_name Pickup
extends Node3D
## An item the player can take. Fires `item_id` on the Events bus (objectives count it),
## shows a message, then removes itself. Stays gone after a checkpoint load (Game flag).

signal picked_up(item_id: StringName)

@export var item_id: StringName = &"item"
@export var display_name: String = "item"

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if Game.get_flag(_flag_key(), false):
		queue_free()
		return
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node3D) -> void:
	interactable.enabled = false
	Game.set_flag(_flag_key())
	picked_up.emit(item_id)
	Events.fire(item_id)
	get_tree().call_group("hud", "show_message", "Picked up: %s" % display_name)
	queue_free()


## Unique per pickup within its level, e.g. "picked:Battery2".
func _flag_key() -> String:
	return "picked:" + str(owner.get_path_to(self) if owner else get_path())
