class_name Inspectable
extends Node3D
## Something the player can pick up and turn over in their hands (InspectView, in the HUD).
## Children: Model (Node3D with only meshes/labels: what gets shown) and Interactable.
##
## - `inspected_event` fires the first time it's looked at (objectives, scares).
## - With an `item_id` it can be taken from the inspect view: fires `item_id` on Events
##   (like a Pickup), is remembered with a Game flag and disappears from the world.

signal inspected
signal taken(item_id: StringName)

@export var title: String = ""
@export_multiline var description: String = ""
@export var inspected_event: StringName
## Empty = look only (put it back). Set = it can be taken.
@export var item_id: StringName

@onready var interactable: Interactable = $Interactable
@onready var model: Node3D = $Model


func _ready() -> void:
	if item_id != &"" and Game.get_flag(_flag_key(), false):
		queue_free()
		return
	interactable.interacted.connect(open)


## Opens the close-up view of this item.
func open(_by: Node3D = null) -> void:
	get_tree().call_group("hud", "inspect", self)
	inspected.emit()
	if inspected_event != &"" and not Events.has_fired(inspected_event):
		Events.fire(inspected_event)


func can_take() -> bool:
	return item_id != &""


## Called by the inspect view when the player takes it.
func take() -> void:
	if not can_take():
		return
	interactable.enabled = false
	Game.set_flag(_flag_key())
	taken.emit(item_id)
	Events.fire(item_id)
	get_tree().call_group("hud", "show_message", "Took: %s" % (title if title != "" else String(item_id)))
	queue_free()


func _flag_key() -> String:
	return "picked:" + str(owner.get_path_to(self) if owner else get_path())
