class_name MethodReaction
extends EventReaction
## Calls a method on nodes, e.g. method "slam" on a Door, or "unlock", or "set_on" with
## args [false] on a LightSwitch. The escape hatch when no dedicated reaction exists.

@export var targets: Array[NodePath] = []
@export var method: StringName
@export var args: Array = []


func _react() -> void:
	for node in _resolve(targets):
		if node.has_method(method):
			node.callv(method, args)
		else:
			push_warning("%s: %s has no method %s" % [get_path(), node.name, method])
