class_name SkinnedBody
extends Node
## Drives a Blender-built character mesh (assets/characters/meshes/<name>.glb, made by
## tools/blender/build_characters.py) from the pivot nodes gen_characters.py builds under
## Body (Pelvis, HipL, KneeL, Chest, ShoulderL, ElbowL, Head, EyelidL ...).
##
## Every frame each bone whose name matches a pivot follows that pivot's motion away from the
## unposed rest (rotation, scale, offset), so CharacterLife (breathing, walking), posed arms
## (the Cameraman's camcorder grip) and NPC head tracking move the mesh exactly as they move
## the pivots. Bones without a pivot (Neck) follow their parent. The eyelid pivots are scaled
## by CharacterLife (0.05 open .. 1 closed); here that turns the upper-lid bone down over the
## eye. Runs after CharacterLife (process_priority).

## Degrees the upper lid turns down when fully closed.
@export var blink_degrees: float = 30.0

var _body: Node3D
var _skel: Skeleton3D
var _order: Array[int] = []
var _pivots: Dictionary = {}       # bone -> Node3D
var _ref_inv: Dictionary = {}      # bone -> inverse of the pivot's unposed rest (Body space)
var _rest_body: Dictionary = {}    # bone -> bone rest pose in Body space
var _skel_to_body: Transform3D
var _skel_to_body_inv: Transform3D
var _global: Dictionary = {}       # bone -> this frame's pose in Body space


func _ready() -> void:
	process_priority = 100
	_body = get_parent().get_node_or_null(^"Body") as Node3D
	if _body == null:
		return
	_skel = _body.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skel == null:
		push_warning("SkinnedBody: no Skeleton3D under %s" % _body.get_path())
		return
	_skel_to_body = _relative(_skel)
	_skel_to_body_inv = _skel_to_body.affine_inverse()
	var depth := {}
	for b in _skel.get_bone_count():
		var d := 0
		var p := _skel.get_bone_parent(b)
		while p >= 0:
			d += 1
			p = _skel.get_bone_parent(p)
		depth[b] = d
		_order.append(b)
		_rest_body[b] = _skel_to_body * _skel.get_bone_global_rest(b)
		var pivot := _body.find_child(_skel.get_bone_name(b), true, false) as Node3D
		if pivot and not (pivot is MeshInstance3D):
			_pivots[b] = pivot
			_ref_inv[b] = _unposed(pivot).affine_inverse()
	_order.sort_custom(func(a: int, b: int) -> bool: return depth[a] < depth[b])
	_tune_materials()
	_update()


func _process(_delta: float) -> void:
	if _skel and _body.is_visible_in_tree():
		_update()


func _update() -> void:
	for b in _order:
		var parent := _skel.get_bone_parent(b)
		var parent_pose: Transform3D = _global[parent] if parent >= 0 else Transform3D()
		var pose: Transform3D
		var name := _skel.get_bone_name(b)
		if name.begins_with("Eyelid") and _pivots.has(b):
			var closed := clampf(((_pivots[b] as Node3D).scale.y - 0.05) / 0.95, 0.0, 1.0)
			pose = parent_pose * _skel.get_bone_rest(b) * Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(blink_degrees) * closed))
			if parent < 0:
				pose = _skel_to_body * pose
		elif _pivots.has(b):
			pose = _relative(_pivots[b]) * (_ref_inv[b] as Transform3D) * (_rest_body[b] as Transform3D)
		elif parent >= 0:
			pose = parent_pose * _skel.get_bone_rest(b)
		else:
			pose = _rest_body[b]
		_global[b] = pose
		var local := (parent_pose.affine_inverse() if parent >= 0 else _skel_to_body_inv) * pose
		_skel.set_bone_pose_position(b, local.origin)
		_skel.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())
		_skel.set_bone_pose_scale(b, local.basis.get_scale())


## `node`'s transform in Body space.
func _relative(node: Node3D) -> Transform3D:
	var t := Transform3D()
	var n: Node = node
	while n and n != _body:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## The pivot's rest with every rotation and scale on the way to Body removed: the pose the
## mesh was modelled in (arms down, head level).
func _unposed(node: Node3D) -> Transform3D:
	var origin := Vector3.ZERO
	var n: Node = node
	while n and n != _body:
		if n is Node3D:
			origin += (n as Node3D).position
		n = n.get_parent()
	return Transform3D(Basis(), origin)


## Skin materials (the painted face and body are a baked texture): a touch of rim light
## stands in for subsurface scattering (web-safe), as on the old characters.
func _tune_materials() -> void:
	for mi in _body.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				continue
			if mat.resource_name.ends_with("_skin"):
				var skin := mat.duplicate() as StandardMaterial3D
				skin.roughness = 0.62
				skin.rim_enabled = true
				skin.rim = 0.15
				skin.rim_tint = 0.6
				(mi as MeshInstance3D).set_surface_override_material(i, skin)
