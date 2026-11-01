extends SceneTree
# Graphics presets: global settings per preset, environment features follow the preset but
# never exceed what a level authored, FPS counter toggle. Restores the player's settings.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_graphics.gd

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
	var settings: Node = root.get_node("Settings")
	var graphics: Node = root.get_node("Graphics")
	var old_quality: int = settings.graphics_quality
	var old_fps: bool = settings.show_fps
	var old_ps1: bool = settings.ps1_mode
	settings.ps1_mode = false  # presets are checked in the default look (PS1 has test_retro)

	var room: Node = load("res://scenes/test/test_room.tscn").instantiate()
	root.add_child(room)
	# A level that did NOT ask for volumetric fog or SSAO:
	var plain := WorldEnvironment.new()
	plain.environment = Environment.new()
	root.add_child(plain)
	await frames(3)
	var env: Environment = room.get_node("WorldEnvironment").environment

	for quality in [0, 1, 2]:
		settings.graphics_quality = quality
		await frames(1)
		var p: Dictionary = graphics.PRESETS[quality]
		var name: String = graphics.NAMES[quality]
		check(is_equal_approx(root.scaling_3d_scale, p.render_scale), "%s: render scale %.2f" % [name, root.scaling_3d_scale])
		check(env.ssao_enabled == p.ssao and env.volumetric_fog_enabled == p.volumetric_fog and env.ssil_enabled == p.ssil,
			"%s: room env follows preset (ssao %s, fog %s, ssil %s)" % [name, env.ssao_enabled, env.volumetric_fog_enabled, env.ssil_enabled])
		check(not plain.environment.volumetric_fog_enabled and not plain.environment.ssao_enabled,
			"%s: preset never adds features a level didn't author" % name)

	settings.graphics_quality = 1
	check(env.volumetric_fog_enabled, "back to MEDIUM restores authored fog")

	settings.show_fps = true
	await create_timer(0.4).timeout
	var label: Label = graphics._fps_label
	check(label.visible and label.text.contains("FPS"), "FPS counter shows ('%s')" % label.text)
	settings.show_fps = false
	check(not label.visible, "FPS counter hides")

	settings.graphics_quality = old_quality
	settings.show_fps = old_fps
	settings.ps1_mode = old_ps1
	room.queue_free()
	plain.queue_free()
	await frames(3)
	print("RESULT fails=", fails)
	quit(fails)
