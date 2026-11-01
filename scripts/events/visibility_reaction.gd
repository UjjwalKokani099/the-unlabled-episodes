class_name VisibilityReaction
extends EventReaction
## Shows or hides nodes (e.g. a figure that appears at the end of a corridor).

@export var targets: Array[NodePath] = []
## true = show them, false = hide them.
@export var make_visible: bool = true
## If above 0, flip them back after this many seconds.
@export var revert_after: float = 0.0


func _react() -> void:
	var nodes := _resolve(targets)
	_set_all(nodes, make_visible)
	if revert_after > 0.0:
		await get_tree().create_timer(revert_after, false).timeout
		if is_inside_tree():
			_set_all(nodes, not make_visible)


func _set_all(nodes: Array[Node], value: bool) -> void:
	for node in nodes:
		if is_instance_valid(node) and "visible" in node:
			node.set(&"visible", value)
