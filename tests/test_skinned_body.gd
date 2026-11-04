extends SceneTree
# Blender-built characters (tools/blender/build_characters.py): every character scene has
# the skinned mesh with the game's bones, SkinnedBody copies the pivots onto the bones (a hip
# swing moves the knee bone, eyelid pivots close the lids, the chest breathes), and the
# Cameraman's posed arms raise his hands to the camcorder.
# Run: <console exe> --path . --quit-after 3000 --script res://tests/test_skinned_body.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func bone_pos(skel: Skeleton3D, name: String) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(name)).origin


func _initialize() -> void:
	await process_frame
	var bones := ["Pelvis", "Chest", "Neck", "Head", "EyelidL", "EyelidR", "ShoulderL", "ShoulderR", "ElbowL",
		"ElbowR", "HipL", "HipR", "KneeL", "KneeR"]
	for name in ["raghu", "deshmukh", "iyer", "cameraman"]:
		var c: Node3D = load("res://assets/characters/%s.tscn" % name).instantiate()
		root.add_child(c)
		await frames(3)
		var skel: Skeleton3D = c.get_node("Body").find_child("Skeleton3D", true, false)
		check(skel != null and bones.all(func(b): return skel.find_bone(b) >= 0), "%s: skinned mesh with the game's bones" % name)
		var height := 0.0
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if mi.get_parent() is Skeleton3D:
				height = maxf(height, mi.get_aabb().end.y)
		check(height > 1.4 and height < 2.0, "%s: human height (%.2f m)" % [name, height])
		if name == "cameraman":
			var hand: Vector3 = bone_pos(skel, "ElbowR")
			check(hand.y > bone_pos(skel, "ShoulderR").y - 0.15, "cameraman: arms raised to the camcorder (elbow %.2f)" % hand.y)
		else:
			var life = c.get_node("Life")
			life.set_process(false)
			var hip: Node3D = c.get_node("Body/Pelvis/HipL")
			var knee0: Vector3 = bone_pos(skel, "KneeL")
			hip.rotation_degrees = Vector3(35, 0, 0)
			await frames(2)
			check(bone_pos(skel, "KneeL").distance_to(knee0) > 0.1, "%s: hip pivot swings the leg bone" % name)
			hip.rotation_degrees = Vector3.ZERO
			var lid: Node3D = c.get_node("Body/Head/EyelidL")
			lid.scale = Vector3(1, 1, 1)
			await frames(2)
			var closed: Quaternion = skel.get_bone_pose_rotation(skel.find_bone("EyelidL"))
			lid.scale = Vector3(1, 0.05, 1)
			await frames(2)
			var open: Quaternion = skel.get_bone_pose_rotation(skel.find_bone("EyelidL"))
			check(closed.angle_to(open) > deg_to_rad(20), "%s: eyelid pivot closes the lid (%.0f deg)" % [name, rad_to_deg(closed.angle_to(open))])
			var chest: Node3D = c.get_node("Body/Chest")
			chest.scale = Vector3(1.03, 1.0, 1.05)
			await frames(2)
			check(skel.get_bone_pose_scale(skel.find_bone("Chest")).z > 1.02, "%s: breathing scales the chest" % name)
		c.queue_free()
		await frames(2)
	print("RESULT fails=%d" % fails)
	quit()
