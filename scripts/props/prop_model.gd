class_name PropModel
extends Node3D
## Put on the root of an instanced 3D model (assets/models/*.gltf) by the level generators
## (tools/propkit.py `model()`): per-instance render options without editing the model.

## Render layer 19: seen by the player, not by CCTV feeds (a camera's own body).
const LAYER_NOT_ON_CCTV := 1 << 18
## Cull mask for CCTV feed cameras: everything (incl. layer 20 CCTV-only) but layer 19.
const CCTV_CULL_MASK := 0xFFFFF & ~LAYER_NOT_ON_CCTV

## Parts of the model to hide (node paths inside it), e.g. a laptop's stand.
@export var hide_parts: PackedStringArray = []
## Render layers for every mesh (e.g. keep a CCTV camera's own body out of its feed).
@export_flags_3d_render var render_layers: int = 1
## Stop drawing beyond this many metres (0 = always). Small clutter in big maps.
@export var visibility_end: float = 0.0
@export var cast_shadows: bool = true


func _ready() -> void:
	for part in hide_parts:
		var node := get_node_or_null(NodePath(part)) as Node3D
		if node:
			node.visible = false
	for node in find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		geo.layers = render_layers
		if not cast_shadows:
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if visibility_end > 0.0:
			geo.visibility_range_end = visibility_end
			geo.visibility_range_end_margin = 2.0
			geo.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
