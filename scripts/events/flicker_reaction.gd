class_name FlickerReaction
extends EventReaction
## Flickers lights (or any Node3D) for a while.
## Lights flicker their brightness, so the player's own on/off (switches, the flashlight
## key) is left alone. Other nodes flicker their visibility.

enum EndState { RESTORE, ON, OFF }

@export var targets: Array[NodePath] = []
@export var duration: float = 1.2
## How targets end up. OFF = the light "dies" (hidden), ON = forced on.
@export var end_state: EndState = EndState.RESTORE
## Shortest / longest time between flicker steps.
@export var min_interval: float = 0.03
@export var max_interval: float = 0.14
## Brightness multiplier during a "dark" flicker step (lights only).
@export var dim_factor: float = 0.04

var is_flickering: bool = false


func _react() -> void:
	var nodes := _resolve(targets)
	var original: Array = []  # light_energy for lights, visible for other nodes
	for node in nodes:
		original.append((node as Light3D).light_energy if node is Light3D else (node as Node3D).visible)

	is_flickering = true
	var elapsed := 0.0
	while elapsed < duration:
		for i in nodes.size():
			_set_lit(nodes[i], original[i], randf() > 0.45)
		var wait := randf_range(min_interval, max_interval)
		await get_tree().create_timer(wait, false).timeout
		if not is_inside_tree():
			return
		elapsed += wait

	for i in nodes.size():
		var node := nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		if node is Light3D:
			(node as Light3D).light_energy = original[i]
			if end_state != EndState.RESTORE:
				node.visible = end_state == EndState.ON
		else:
			node.visible = original[i] if end_state == EndState.RESTORE else end_state == EndState.ON
	is_flickering = false


func _set_lit(node: Node, original_value: Variant, lit: bool) -> void:
	if not is_instance_valid(node):
		return
	if node is Light3D:
		(node as Light3D).light_energy = original_value * (1.0 if lit else dim_factor)
	else:
		(node as Node3D).visible = original_value and lit
