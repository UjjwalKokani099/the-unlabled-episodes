extends SceneTree
## Measures performance on THIS machine, for every graphics preset.
##
## Usage (from the project root):
##   <console exe> --path . --script res://tools/benchmark.gd -- [scene] [seconds_per_point]
## Defaults: the test room, 3 seconds per point.
##
## Runs fullscreen at the desktop resolution with VSync off. The camera visits every
## Marker3D in the "benchmark_points" group (or just the player's spawn) and turns a full
## circle at each. Reports average FPS, 1% low FPS (the worst 1% of frames) and GPU time
## per frame. The player's own settings are restored afterwards.

const WARMUP_SECONDS := 1.5

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/test/test_room.tscn"
	var per_point := float(args[1]) if args.size() > 1 else 3.0
	var settings: Node = root.get_node("Settings")
	var saved_quality: int = settings.graphics_quality

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file(scene_path)
	await scene_changed
	await _wait(0.5)
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)

	var player = get_first_node_in_group("player")
	var points: Array[Transform3D] = []
	for marker in get_nodes_in_group("benchmark_points"):
		points.append((marker as Node3D).global_transform)
	if points.is_empty() and player:
		points.append(player.global_transform)
	if player:
		player.input_enabled = false

	print("")
	print("BENCH scene=%s  resolution=%s  points=%d  %.1fs each" % [scene_path, root.size, points.size(), per_point])
	print("BENCH %-7s %8s %8s %8s %8s" % ["preset", "avg fps", "1% low", "gpu ms", "cpu ms"])
	for quality in [0, 1, 2]:
		settings.graphics_quality = quality
		if player:
			player.teleport(points[0])
		await _wait(WARMUP_SECONDS)  # let shaders compile and fog/AO settle
		var frame_ms: Array[float] = []
		var gpu_ms: Array[float] = []
		var cpu_ms: Array[float] = []
		for point in points:
			if player:
				player.teleport(point)
			var elapsed := 0.0
			while elapsed < per_point:
				var start := Time.get_ticks_usec()
				await process_frame
				var dt := (Time.get_ticks_usec() - start) / 1000.0
				frame_ms.append(dt)
				gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
				cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
				elapsed += dt / 1000.0
				if player:
					player.rotation.y += TAU * (dt / 1000.0) / per_point
		print("BENCH %-7s %8.1f %8.1f %8.2f %8.2f" % [
			["LOW", "MEDIUM", "HIGH"][quality], 1000.0 / _mean(frame_ms),
			1000.0 / _percentile(frame_ms, 0.99), _mean(gpu_ms), _mean(cpu_ms)])

	settings.graphics_quality = saved_quality
	current_scene.queue_free()
	await process_frame
	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1)


func _percentile(values: Array[float], p: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(sorted.size() * p), 0, sorted.size() - 1)]
