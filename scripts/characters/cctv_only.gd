class_name CCTVOnly
extends Node3D
## Everything under this node is seen only by CCTV cameras, never by the player's own eyes
## (render layer 20; the player camera's cull mask leaves it out). Story: Deshmukh standing
## on his balcony on the monitor, while the real balcony is empty.
## Lights under it light only CCTV-only things.

const LAYER := 1 << 19


func _ready() -> void:
	apply_to(self)


## Puts every visual under `node` on the CCTV-only layer.
static func apply_to(node: Node) -> void:
	for child in node.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = LAYER
		if child is Light3D:
			(child as Light3D).light_cull_mask = LAYER
		apply_to(child)
