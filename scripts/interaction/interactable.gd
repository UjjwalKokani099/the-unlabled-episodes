class_name Interactable
extends Area3D
## Makes something usable: the player looks at it (within reach) and presses E.
##
## React analogy: a wrapper that gives any object an onClick. Add an Interactable
## (Area3D + CollisionShape3D) as a child of a prop, then connect to `interacted`
## from the prop's own script. The prop decides what "use" means.

signal interacted(by: Node3D)
signal focus_entered
signal focus_exited

## Physics layer 3 ("interactable"), as a bitmask value.
const LAYER := 4

## Text after the key in the HUD prompt, e.g. "[E] Open".
@export var prompt: String = "Use"
## 0 = press once. Above 0 = seconds the key must be held.
@export_range(0.0, 10.0, 0.1) var hold_time: float = 0.0
## Disabled interactables can't be focused or used.
@export var enabled: bool = true


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false


func interact(by: Node3D) -> void:
	if enabled:
		interacted.emit(by)
