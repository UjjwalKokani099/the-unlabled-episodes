class_name NavBaker
extends NavigationRegion3D
## Bakes this region's NavigationMesh when the level loads (on a thread), from the static
## colliders of the nodes in `source_paths` (kit levels: "../Collision"). Generated levels
## change often, so baking at runtime keeps the navmesh in sync for free. NPCs walk on it.
## Limit the work with the mesh's filter_baking_aabb (e.g. ground floor only).

signal baked

@export var source_paths: Array[NodePath] = [NodePath("../Collision")]

var is_baked: bool = false


func _ready() -> void:
	var group := navigation_mesh.geometry_source_group_name
	for path in source_paths:
		var node := get_node_or_null(path)
		if node:
			node.add_to_group(group)
	bake_finished.connect(func() -> void:
		is_baked = true
		baked.emit())
	bake_navigation_mesh(true)
