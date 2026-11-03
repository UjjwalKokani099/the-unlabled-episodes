class_name StaticBatcher
extends Node3D
## Merges every MeshInstance3D below this node into a few big meshes: one per material per
## grid cell. Kit-built levels contain thousands of small boxes; drawing each one separately
## would cost thousands of draw calls. After merging, the originals are freed.
##
## Only put geometry that never moves under this node (walls, slabs, steps, grills).
## Moving things (doors, props you pick up) must live elsewhere.

## Size of the grid cells (metres). Smaller = better culling, more draw calls.
@export var cell_size: float = 16.0
## Hide merged chunks beyond this distance (0 = never). Keeps distant clutter cheap.
@export var visibility_range: float = 0.0

## Filled after merging: number of meshes before and after (for tests / stats).
var merged_from: int = 0
var merged_into: int = 0


func _ready() -> void:
	_merge()


func _merge() -> void:
	var groups := {}  # key "material|cell" -> {"material": Material, "tool": SurfaceTool, "shadow": int}
	var originals: Array[MeshInstance3D] = []
	var inverse := global_transform.affine_inverse()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.is_in_group(&"no_batch"):
			continue
		var material: Material = mi.material_override
		if material == null:
			material = mi.mesh.surface_get_material(0)
		var local := inverse * mi.global_transform
		var cell := Vector3i((local.origin / cell_size).floor())
		var key := "%d|%s|%d" % [material.get_instance_id() if material else 0, cell, mi.cast_shadow]
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"material": material, "tool": st, "shadow": mi.cast_shadow}
		for surface in mi.mesh.get_surface_count():
			(groups[key].tool as SurfaceTool).append_from(mi.mesh, surface, local)
		originals.append(mi)

	merged_from = originals.size()
	for mi in originals:
		mi.get_parent().remove_child(mi)
		mi.queue_free()

	var index := 0
	for key in groups:
		var entry: Dictionary = groups[key]
		var st: SurfaceTool = entry.tool
		var mesh := st.commit()
		var out := MeshInstance3D.new()
		out.name = "Batch%d" % index
		out.mesh = mesh
		out.material_override = entry.material
		out.cast_shadow = entry.shadow
		if visibility_range > 0.0:
			out.visibility_range_end = visibility_range
			out.visibility_range_end_margin = 4.0
			out.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(out)
		index += 1
	merged_into = index
