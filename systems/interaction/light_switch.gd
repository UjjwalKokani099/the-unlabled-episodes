class_name LightSwitch
extends Node3D
## Wall switch that turns a set of lights on and off. Faces +Z. Its state is part of the
## checkpoint (group "persist").

signal toggled(is_on: bool)

## Lights (or any Node3D) to show/hide, relative to this switch.
@export var light_paths: Array[NodePath] = []
@export var is_on: bool = true

const CLICK: SoundSet = preload("res://data/sounds/switch_click.tres")

@onready var interactable: Interactable = $Interactable
@onready var lever: Node3D = $Lever


func _ready() -> void:
	add_to_group("persist")
	interactable.interacted.connect(func(_by: Node3D) -> void: set_on(not is_on))
	interactable.default_tick = false
	_apply()


func set_on(on: bool) -> void:
	if on == is_on:
		return
	AudioManager.play_set_at(CLICK, global_position, -6.0, 2.0)
	is_on = on
	_apply()
	toggled.emit(is_on)


func save_state() -> Dictionary:
	return {"on": is_on}


func load_state(state: Dictionary) -> void:
	is_on = bool(state.get("on", is_on))
	_apply()


func _apply() -> void:
	for path in light_paths:
		var target := get_node_or_null(path) as Node3D
		if target == null:
			continue
		# Fixtures with an `on` switch (TubeLight) keep their body visible and just go dark.
		if &"on" in target:
			target.set(&"on", is_on)
		else:
			target.visible = is_on
	lever.rotation.x = deg_to_rad(-20.0 if is_on else 20.0)
	interactable.prompt = "Turn off light" if is_on else "Turn on light"
