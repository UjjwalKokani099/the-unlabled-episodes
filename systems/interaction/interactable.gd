class_name Interactable
extends Area3D
## Makes something usable: the player looks at it (within reach) and presses E.
##
## React analogy: a wrapper that gives any object an onClick. Add an Interactable
## (Area3D + CollisionShape3D) as a child of a prop, then connect to `interacted`
## from the prop's own script. The prop decides what "use" means.

signal interacted(by: Node3D)

const TICK: SoundSet = preload("res://data/sounds/interact_tick.tres")
signal focus_entered
signal focus_exited

## Physics layer 3 ("interactable"), as a bitmask value.
const LAYER := 4

## Text after the key in the HUD prompt, e.g. "[E] Open".
@export var prompt: String = "Use"
## 0 = press once. Above 0 = seconds the key must be held.
@export_range(0.0, 10.0, 0.1) var hold_time: float = 0.0
## Disabled interactables can't be focused or used, and don't block the look-ray
## (they leave the interactable physics layer).
## Sound played on use (a SoundSet). Leave empty for the generic soft tick.
@export var use_sounds: SoundSet
## Owners that play their own sounds (doors, drawers, switches, pickups) turn this off.
@export var default_tick: bool = true
@export var enabled: bool = true:
	set(value):
		enabled = value
		collision_layer = LAYER if enabled else 0


func _ready() -> void:
	collision_layer = LAYER if enabled else 0
	collision_mask = 0
	monitoring = false


func interact(by: Node3D) -> void:
	if not enabled:
		return
	interacted.emit(by)
	# Nothing happens silently: a soft tick unless the owner plays its own sound.
	if use_sounds:
		AudioManager.play_set_at(use_sounds, global_position, -4.0)
	elif default_tick:
		AudioManager.play_set_at(TICK, global_position, -12.0, 2.0)
