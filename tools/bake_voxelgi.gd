extends SceneTree
## Bakes every VoxelGI in a scene and saves its data next to the scene as <scene>_gi.res
## (one VoxelGI per scene is supported; the generator then references that file).
## Usage: <console exe> --path . --script res://tools/bake_voxelgi.gd -- res://chapters/hub/nikhil_room.tscn

func _initialize() -> void:
	await process_frame
	var path: String = OS.get_cmdline_user_args()[0]
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	for i in 5:
		await process_frame  # let StaticBatcher merge first
	var out := path.get_basename() + "_gi.res"
	for gi in scene.find_children("*", "VoxelGI", true, false):
		(gi as VoxelGI).bake(scene)
		var err := ResourceSaver.save((gi as VoxelGI).data, out)
		print("baked %s -> %s (error %d)" % [gi.name, out, err])
	scene.queue_free()
	await process_frame
	quit()
