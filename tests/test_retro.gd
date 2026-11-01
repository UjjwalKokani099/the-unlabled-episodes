extends SceneTree
# Phase 2 look options: PS1 mode (render scale, no FXAA, global shader value, pixelate
# pass) and the camcorder's night vision (IR light, battery drain, pickups, dead battery).
# Separate save file; restores the player's settings.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_retro.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var settings: Node = root.get_node("Settings")
	var events: Node = root.get_node("Events")
	var was_ps1: bool = settings.ps1_mode
	game.save_path = "user://test_save.json"
	game.delete_save()
	check(game.start_chapter(&"tape_00_test"), "test chapter starts")
	await game.transition_finished
	var cam = get_first_node_in_group("camcorder")

	# --- PS1 mode ---
	settings.ps1_mode = false
	await frames(2)
	var normal_scale: float = root.scaling_3d_scale
	settings.ps1_mode = true
	await frames(2)
	check(root.scaling_3d_scale <= 0.5 and root.scaling_3d_scale < normal_scale + 0.001, "PS1: 3D at half resolution (%.2f)" % root.scaling_3d_scale)
	check(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "PS1: no FXAA")
	check(is_equal_approx(root.get_node("Graphics").ps1_amount, 1.0), "PS1: shaders wobble/warp/point-sample")
	check(cam._retro.visible, "PS1: pixelate + dither pass on")
	settings.ps1_mode = false
	await frames(2)
	check(is_equal_approx(root.scaling_3d_scale, normal_scale) and not cam._retro.visible
		and is_equal_approx(root.get_node("Graphics").ps1_amount, 0.0), "PS1 off: back to the default look")

	# --- Night vision ---
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	var ev := InputEventAction.new()
	ev.action = &"night_vision"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(3)
	check(cam.night_vision and cam.osd.get_node("Mode").text.contains("NIGHT"), "N switches night vision on (OSD says NIGHT)")
	check(camera.get_children().any(func(n): return n is OmniLight3D), "IR fill light on the camera")
	var before: float = cam.osd.battery_level
	await create_timer(1.0).timeout
	check(cam.osd.battery_level < before, "battery drains (%.3f -> %.3f)" % [before, cam.osd.battery_level])
	cam.osd.battery_level = 0.1
	events.fire(&"battery")
	check(cam.osd.battery_level > 0.55, "a battery pickup recharges it")
	cam.osd.battery_level = 0.0
	await frames(3)
	check(not cam.night_vision, "dead battery: night vision cuts out")
	cam.set_night_vision(true)
	check(not cam.night_vision, "can't switch on with a dead battery")
	await frames(3)
	check(not camera.get_children().any(func(n): return n is OmniLight3D and not n.is_queued_for_deletion()), "IR light removed")

	settings.ps1_mode = was_ps1
	game.delete_save()
	current_scene.queue_free()
	await frames(3)
	print("RESULT fails=", fails)
	quit(fails)
