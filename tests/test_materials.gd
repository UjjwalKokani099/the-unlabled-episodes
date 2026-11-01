extends SceneTree
# Material library + decals: every material loads with its textures, textures are
# VRAM-compressed with mipmaps, decal scenes load and project with a texture.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_materials.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		print("FAIL " + msg)
		fails += 1

func _initialize() -> void:
	await process_frame
	var materials := 0
	for file in DirAccess.get_files_at("res://assets/materials"):
		if not file.ends_with(".tres"):
			continue
		materials += 1
		var loaded: Material = load("res://assets/materials/" + file)
		check(loaded != null, "%s loads" % file)
		var mat := loaded as ShaderMaterial
		if mat == null:
			continue  # plain StandardMaterial3D (glass, door panel, emissive lamp glass)
		for param in ["albedo_tex", "normal_tex", "roughness_tex"]:
			var tex := mat.get_shader_parameter(param) as Texture2D
			check(tex != null, "%s has %s" % [file, param])
			if tex:
				var image := tex.get_image()
				check(image.is_compressed(), "%s %s is VRAM-compressed" % [file, param])
				check(image.has_mipmaps(), "%s %s has mipmaps" % [file, param])
		check(float(mat.get_shader_parameter("tile_size")) > 0.1, "%s has a real tile size" % file)
	print("PASS %d materials checked" % materials)
	check(materials >= 30, "library has %d materials (expected 30+)" % materials)

	var decals := 0
	for file in DirAccess.get_files_at("res://scenes/decals"):
		if not file.ends_with(".tscn"):
			continue
		decals += 1
		var scene: Node = load("res://scenes/decals/" + file).instantiate()
		var decal := scene.get_node_or_null("Decal") as Decal
		check(decal != null and decal.texture_albedo != null, "%s has a textured Decal" % file)
		if decal:
			var projects: Vector3 = -(Basis.from_euler(decal.rotation) * Vector3.UP)
			check(projects.is_equal_approx(Vector3.FORWARD), "%s projects along -Z (into the wall)" % file)
		scene.free()
	print("PASS %d decals checked" % decals)
	check(decals >= 10, "found %d decals (expected 10+)" % decals)

	var gallery: Node = load("res://scenes/test/material_gallery.tscn").instantiate()
	root.add_child(gallery)
	for i in 5:
		await process_frame
	check(gallery.get_node("TubeLight2").flicker > 0.0, "gallery has a flickering tube light")
	gallery.queue_free()
	await process_frame
	print("RESULT fails=", fails)
	quit(fails)
