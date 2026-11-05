extends SceneTree
# Walkthrough / trailer footage: drives the real game (boot -> menu -> Nikhil's room -> Tape 1:
# cabin, courtyard, flat 4B, the ending + END OF TAPE -> a Tape 2 teaser -> the logo card) with
# a scripted camera, recorded by Godot's Movie Maker at a fixed frame rate (every frame, with
# the game's audio, however slow the machine). ~2 minutes.
#   <console exe> --path . --resolution 1920x1080 --write-movie build/walkthrough.avi --fixed-fps 30 \
#       --script res://tools/record_walkthrough.gd
#   ffmpeg -i build/walkthrough.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac walkthrough.mp4
# Uses its own save file and leaves the player's settings alone.
const LOG := "WALK "
var game
var ev
var p
var cam_dir := Vector3.FORWARD


func mark(name: String) -> void:
	print(LOG, "%s at frame %d" % [name, Engine.get_frames_drawn()])


func secs(t: float) -> void:
	await create_timer(t).timeout


func until(cond: Callable, limit: float = 30.0) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await process_frame
		t += root.get_process_delta_time()


func player_ready() -> void:
	p = get_first_node_in_group("player")
	if p:
		p.input_enabled = false
		p.noclip = true


func aim(pos: Vector3, target: Vector3) -> void:
	p.global_position = pos
	var to := (target - (pos + Vector3(0, 1.6, 0))).normalized()
	p.rotation.y = atan2(-to.x, -to.z)
	var pitch := rad_to_deg(asin(clampf(to.y, -1, 1)))
	p.set(&"_pitch", pitch)
	p.head.rotation.x = deg_to_rad(pitch)


# Glide through keys [[pos, look_target], ...] over `seconds`, smoothstep between keys.
func glide(keys: Array, seconds: float) -> void:
	var n := keys.size() - 1
	var t := 0.0
	while true:
		var u: float = clampf(t / seconds, 0.0, 1.0) * n
		var i := mini(int(u), n - 1)
		var k := smoothstep(0.0, 1.0, u - i)
		var pos: Vector3 = keys[i][0].lerp(keys[i + 1][0], k)
		var look: Vector3 = keys[i][1].lerp(keys[i + 1][1], k)
		aim(pos, look)
		if t >= seconds:
			break
		await process_frame
		t += root.get_process_delta_time()


func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	ev = root.get_node("EventBus")
	game.save_path = "user://walkthrough_save.json"
	game.delete_save()
	game.mark_intro_seen()
	game.chapter_complete_wait = 60.0
	# load everything before the first recorded frame, so loading cards only hold their normal time
	for path in ["res://ui/menus/boot.tscn", "res://ui/menus/main_menu.tscn", "res://chapters/hub/hub.tscn",
			"res://chapters/chapter_01/shanti_vihar.tscn", "res://chapters/chapter_02/toll_plaza.tscn"]:
		load(path)
	game.get_chapter(&"tape_02_wip").subtitle = "THE TOLL BOOTH"

	# ---- A. boot -> menu
	mark("boot")
	change_scene_to_file("res://ui/menus/boot.tscn")
	await secs(3.2)
	await secs(3.3)  # content warning
	current_scene.advance()
	await until(func() -> bool: return current_scene and current_scene.name == "MainMenu")
	mark("menu")
	await secs(6.5)

	# ---- B. Nikhil's room: look around, the box, the VCR
	game.enter_hub()
	await game.transition_finished
	mark("hub")
	player_ready()
	var hub = current_scene
	await glide([[Vector3(1.4, 0, 1.0), Vector3(1.8, 1.2, 3.5)], [Vector3(1.6, 0, 1.3), Vector3(3.2, 0.9, 3.7)],
		[Vector3(2.0, 0, 1.8), Vector3(3.4, 1.0, 1.2)], [Vector3(2.0, 0, 2.0), Vector3(3.15, 0.85, 3.6)]], 9.0)
	hub.use_box()
	await secs(1.0)
	hub.use_vcr()
	await secs(2.0)

	# ---- C. Tape 1: the cabin, the courtyard, a cut to 4B, the ending
	await until(func() -> bool: return current_scene and current_scene.name == "ShantiVihar", 40.0)
	await game.transition_finished
	mark("tape1")
	player_ready()
	var lv = current_scene
	await glide([[Vector3(5.5, 0, 23.3), Vector3(7.0, 0.95, 25.0)], [Vector3(5.7, 0, 23.6), Vector3(6.3, 0.8, 24.85)],
		[Vector3(5.2, 0, 23.4), Vector3(3.0, 1.5, 23.0)]], 8.0)
	await glide([[Vector3(4.8, 0, 23.0), Vector3(2.0, 1.6, 22.5)], [Vector3(3.0, 0, 22.0), Vector3(0, 2.0, 12)],
		[Vector3(1.0, 0, 16.0), Vector3(-4, 4.0, -10)], [Vector3(-1.5, 0, 6.0), Vector3(-4.25, 12.5, -20.6)]], 12.0)
	var camcorder = get_first_node_in_group("camcorder")
	camcorder.tape_cut("03:24:10")
	await secs(0.6)
	aim(Vector3(-5.8, 12.05, -20.0), Vector3(-7.2, 13.9, -14.1))
	await camcorder.cut_finished
	mark("flat4b")
	await glide([[Vector3(-5.8, 12.05, -20.0), Vector3(-7.2, 13.9, -14.1)], [Vector3(-6.8, 12.05, -16.6), Vector3(-7.2, 14.2, -14.1)]], 6.0)
	camcorder.tape_cut("03:41:30")
	await secs(0.6)
	aim(Vector3(28.4, 0.05, -3.2), Vector3(28.6, 1.4, -2.2))
	await camcorder.cut_finished
	mark("meter_room")
	lv.get_node("Story/Sequences").play("t1_ending")
	var found := []
	await until(func() -> bool:
		for c in root.get_children():
			if c is CanvasLayer and c.has_method("is_showing_card") and c.is_showing_card():
				found.append(c)
				return true
		return false, 60.0)
	var screen = found[0]
	mark("end_of_tape")
	await secs(3.5)
	screen.continue_now()
	await game.transition_finished

	# ---- D. Tape 2 teaser
	game.start_chapter(&"tape_02_wip")
	await game.transition_finished
	mark("tape2")
	player_ready()
	var lv2 = current_scene
	var story = lv2.get_node("Story")
	for i in 4:
		game.set_flag("t2_cut_%d" % (i + 1), true)
	ev.replaying = true
	for id in [&"radio_checkin", &"vehicle_served", &"vehicle_served", &"vehicle_served", &"log_written", &"van_served_1",
			&"radio_van", &"van_served_2", &"lane_checked", &"van_served_3", &"radio_dead"]:
		ev.fire(id)
	ev.replaying = false
	story.time_scale = 0.35
	story._advance()
	var van = lv2.get_node("Vehicles/Van")
	aim(Vector3(0.35, 0.26, 0.2), Vector3(-2.7, 1.2, 40))
	await until(func() -> bool: return van.visible, 10.0)
	await glide([[Vector3(0.35, 0.26, 0.2), Vector3(-2.7, 1.0, 30)], [Vector3(0.35, 0.26, 0.2), Vector3(-2.7, 1.1, 6)]], 3.0)
	await until(func() -> bool: return van.is_waiting(), 15.0)
	await glide([[Vector3(0.35, 0.26, 0.2), Vector3(-2.6, 1.3, 1.0)], [Vector3(0.2, 0.26, 0.2), Vector3(-2.7, 1.3, 2.3)]], 4.0)
	await glide([[Vector3(-7.5, 0.0, 8.0), Vector3(-2.7, 1.2, 1.5)], [Vector3(-6.0, 0.0, 4.5), Vector3(-2.7, 1.2, 1.5)]], 5.0)
	aim(Vector3(0.35, 0.26, 0.2), Vector3(-2.7, 1.3, 2.25))
	story.lights_die()
	await secs(2.0)
	story.red_dot()
	await secs(3.0)
	get_first_node_in_group("camcorder").show_static()
	await secs(1.2)

	# ---- E. logo card
	mark("logo")
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/logo_vhs.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.offset_bottom = -90
	logo.modulate.a = 0.0
	layer.add_child(logo)
	var line := Label.new()
	line.text = "TIMELESS STUDIOS   -   DEMO: TAPE 01 THE WATCHMAN"
	line.add_theme_font_override(&"font", load("res://assets/fonts/vcr.tres"))
	line.add_theme_font_size_override(&"font_size", 28)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -110
	line.offset_bottom = -60
	line.modulate.a = 0.0
	layer.add_child(line)
	AudioManager_stop()
	var tw := logo.create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(line, "modulate:a", 0.85, 1.6)
	await secs(5.5)
	var tw2 := logo.create_tween()
	tw2.tween_property(logo, "modulate:a", 0.0, 1.0)
	tw2.parallel().tween_property(line, "modulate:a", 0.0, 1.0)
	await secs(1.3)
	mark("end")
	game.delete_save()
	game.save_path = root.get_node("SaveManager").DEFAULT_PATH
	game.quit_game()


func AudioManager_stop() -> void:
	var am = root.get_node("AudioManager")
	am.set_tension(0.0, &"story")
	am.set_ambience(null, 1.0)
