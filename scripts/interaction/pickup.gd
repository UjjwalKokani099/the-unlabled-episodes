class_name Pickup
extends Node3D
## An item the player can take. Emits `picked_up`, shows a message, then removes itself.
## (The objectives system will listen for `picked_up`.)

signal picked_up(item_id: StringName)

@export var item_id: StringName = &"item"
@export var display_name: String = "item"

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node3D) -> void:
	interactable.enabled = false
	picked_up.emit(item_id)
	get_tree().call_group("hud", "show_message", "Picked up: %s" % display_name)
	queue_free()
