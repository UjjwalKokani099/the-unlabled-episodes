extends SceneTree
## Renderer-side profile of a level for docs/performance.md (studio spec 12): at each
## benchmark point (group "benchmark_points", else the spawn), four headings, it records draw
## calls, objects and primitives drawn, plus the scene's node/object/resource counts and
## static + video memory. Draw calls and primitives depend on the scene and renderer, not the
## GPU, so they are valid from the cloud (lavapipe); frame times are only real on the laptop
## (tools/benchmark.gd).
## Usage: <console exe> --path . [--rendering-method X] --script res://tools/profile_level.gd -- <scene> [quality 0-2] [lod px]

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://chapters/chapter_01/shanti_vihar.tscn"
	var settings: Node = root.get_node("SettingsManager")
	var saved_quality: int = settings.graphics_quality
	if args.size() > 1:
		settings.graphics_quality = int(args[1])
	if args.size() > 2:
		root.mesh_lod_threshold = float(args[2])
	change_scene_to_file(scene_path)
	await scene_changed
	await create_timer(1.5).timeout
	var player = get_first_node_in_group("player")
	if player:
		player.input_enabled = false
	var points: Array[Transform3D] = []
	for marker in get_nodes_in_group("benchmark_points"):
		points.append((marker as Node3D).global_transform)
	if points.is_empty() and player:
		points.append(player.global_transform)
	var worst := {"draw": 0, "objects": 0, "prims": 0}
	var sum := {"draw": 0.0, "objects": 0.0, "prims": 0.0}
	var n := 0
	for point in points:
		for heading in 4:
			if player:
				var t := point
				t.basis = Basis(Vector3.UP, heading * PI / 2.0)
				player.teleport(t)
			for f in 6:
				await process_frame
			var draw := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			worst.draw = maxi(worst.draw, draw)
			worst.objects = maxi(worst.objects, objs)
			worst.prims = maxi(worst.prims, prims)
			sum.draw += draw
			sum.objects += objs
			sum.prims += prims
			n += 1
	print("PROFILE %s | %s | lod %.1f | q%d | points %d | draw calls avg %d max %d | objects avg %d max %d | primitives avg %dk max %dk | nodes %d | objects %d | resources %d | static %.0f MB | video %.0f MB" % [
		scene_path.get_file(), RenderingServer.get_current_rendering_method(), root.mesh_lod_threshold, settings.graphics_quality, points.size(),
		sum.draw / n, worst.draw, sum.objects / n, worst.objects, sum.prims / n / 1000, worst.prims / 1000,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	settings.graphics_quality = saved_quality
	current_scene.queue_free()
	await process_frame
	quit()
