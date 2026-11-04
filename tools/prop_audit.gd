extends RefCounted
## Floating-prop audit (studio spec 11: "no floating props"), used by tools/check_props.gd and
## tests/test_polish.gd. For every prop under the level's Props node, casts short rays down
## from just above the bottom of its visual bounds (centre + four inner points): nothing solid
## within 8 cm below = floating. Wall/ceiling/stacked props carry metadata/mount (propkit
## `mount=`) and are skipped. The level must be in the tree for a physics frame first.


## Names + heights of floating props: ["Name bottom=1.23 at (x, z)", ...].
static func floating(level: Node3D) -> PackedStringArray:
	var out := PackedStringArray()
	var space := level.get_world_3d().direct_space_state
	var props := level.get_node_or_null("Props")
	if props == null:
		return out
	for p in props.get_children():
		if not (p is Node3D) or String(p.get_meta(&"mount", "")) != "":
			continue
		var box := bounds(p)
		if box.size == Vector3.ZERO or box.position.y <= 0.03:
			continue
		var c := box.get_center()
		var grounded := false
		for off: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(-0.3, -0.3)]:
			var at := Vector3(c.x + box.size.x * off.x, box.position.y + 0.04, c.z + box.size.z * off.y)
			var q := PhysicsRayQueryParameters3D.create(at, at - Vector3(0, 0.12, 0), 1)
			if not space.intersect_ray(q).is_empty():
				grounded = true
				break
		if not grounded:
			out.append("%s bottom=%.2f at (%.2f, %.2f)" % [p.name, box.position.y, c.x, c.z])
	return out


## World bounds of a node's visible meshes.
static func bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		if not (m is MeshInstance3D or m is MultiMeshInstance3D) or not (m as Node3D).visible:
			continue
		var b: AABB = (m as VisualInstance3D).global_transform * (m as VisualInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
