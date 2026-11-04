extends SceneTree
# Camera effects: VHS strength setting, glitch decay, camera shake, OSD clock + REC blink.
# Run: <console exe> --path . --quit-after 4000 --script res://tests/test_camera.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await process_frame

# Frame rate is uncapped in test runs, so time-based checks wait real seconds.
func seconds(s: float) -> void:
	await create_timer(s).timeout

func _initialize() -> void:
	await process_frame
	var settings: Node = root.get_node("SettingsManager")
	var old_effects: float = settings.screen_effects
	var old_sway: bool = settings.camera_sway
	settings.screen_effects = 1.0
	var room: Node = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	await frames(10)
	var camcorder = room.get_node("Camcorder")
	var vhs = camcorder.vhs
	var mat: ShaderMaterial = vhs.material
	var camera: Camera3D = room.get_node("Player/Head/Camera3D")
	var shake = room.get_node("Player/Head/Camera3D/CameraShake")

	# --- VHS strength follows the setting ---
	check(is_equal_approx(mat.get_shader_parameter("strength"), 1.0) and vhs.visible, "VHS on at full strength")
	settings.screen_effects = 0.5
	check(is_equal_approx(mat.get_shader_parameter("strength"), 0.5), "strength follows setting (0.5)")
	settings.screen_effects = 0.0
	check(not vhs.visible, "effect hidden at 0")
	settings.screen_effects = 1.0
	check(vhs.visible, "effect back at 1")

	# --- Glitch spikes then fades ---
	room.get_tree().call_group("camcorder", "glitch", 0.9, 0.5)
	check(is_equal_approx(mat.get_shader_parameter("glitch"), 0.9), "glitch spikes to 0.9")
	await seconds(0.2)
	var mid: float = mat.get_shader_parameter("glitch")
	check(mid > 0.1 and mid < 0.9, "glitch fading (%.2f)" % mid)
	await seconds(0.45)
	check(mat.get_shader_parameter("glitch") == 0.0, "glitch gone after its duration")
	vhs.glitch(0.8, 1.0)
	vhs.glitch(0.3, 1.0)
	check(is_equal_approx(vhs.get_glitch(), 0.8), "weaker glitch doesn't cut a stronger one short")
	await seconds(1.1)

	# --- Camera shake ---
	settings.camera_sway = false
	await frames(2)
	check(camera.rotation.length() < 0.0001, "no rotation when calm and sway is off")
	room.get_tree().call_group("camera_shake", "add_trauma", 0.8)
	var peak := 0.0
	var until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < until:
		await process_frame
		peak = maxf(peak, camera.rotation.length())
	check(peak > deg_to_rad(0.5), "shake rotates the camera (peak %.2f deg)" % rad_to_deg(peak))
	await seconds(1.0)
	check(shake.trauma == 0.0 and camera.rotation.length() < 0.0001, "shake settles")
	settings.camera_sway = true
	var sway := 0.0
	until = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until:
		await process_frame
		sway = maxf(sway, camera.rotation.length())
	check(sway > 0.0 and sway < deg_to_rad(0.6), "hand-held sway is subtle (%.2f deg)" % rad_to_deg(sway))

	# --- CameraReaction via Events ---
	room.get_node("Scares/FigureGlitch").trigger()
	await frames(1)
	check(vhs.get_glitch() > 0.8 and shake.trauma > 0.2, "CameraReaction glitches + shakes")

	# --- OSD ---
	var osd = camcorder.osd
	check(osd.get_node("Date").text == "OCT. 31 1998", "date '%s'" % osd.get_node("Date").text)
	check(osd.get_node("Time").text.begins_with("PM 11:42:0"), "time '%s'" % osd.get_node("Time").text)
	var t0: String = osd.get_node("Time").text
	var rec_states := {}
	until = Time.get_ticks_msec() + 2200
	while Time.get_ticks_msec() < until:
		await process_frame
		rec_states[osd.get_node("Rec").visible] = true
	check(osd.get_node("Time").text != t0, "clock ticks (%s -> %s)" % [t0, osd.get_node("Time").text])
	check(rec_states.has(true) and rec_states.has(false), "REC blinks (states seen: %s)" % [rec_states.keys()])

	room.queue_free()
	settings.screen_effects = old_effects
	settings.camera_sway = old_sway
	await frames(2)
	print("RESULT fails=", fails)
	quit(fails)
