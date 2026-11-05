extends SceneTree
# Tape 1 walkthrough footage (Movie Maker): the whole night played by a script with real
# walking (physics, head bob, footsteps), real interactions, the conversations, the spots and
# the ending. Boot + menu briefly, then Tape 1 only. ~8 minutes.
#   <console exe> --path . --resolution 1920x1080 --write-movie build/tape01.avi --fixed-fps 30 \
#       --script res://tools/record_tape01.gd
#   ffmpeg -i build/tape01.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac tape01.mp4
# Own save file; settings untouched. The player is driven through InputManager's gamepad mode
# (counts as "playing" without a captured mouse), pressing the real move actions.
const LOG := "WALK "
var game
var ev
var p
var lv


func mark(name: String) -> void:
	print(LOG, "%s at frame %d" % [name, Engine.get_frames_drawn()])


func dt() -> float:
	return root.get_process_delta_time()


func secs(t: float) -> void:
	await create_timer(t).timeout


func until(cond: Callable, limit: float = 30.0) -> bool:
	var t := 0.0
	while not cond.call() and t < limit:
		await process_frame
		t += dt()
	return cond.call()


func drive_on() -> void:
	var im = root.get_node("InputManager")
	im.device = 1  # GAMEPAD: "playing" without a captured mouse (xvfb can't always grab it)
	im.set(&"_want_capture", true)
	p = get_first_node_in_group("player")
	p.input_enabled = true
	p.noclip = false


func release() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(a)


func set_pitch(deg: float) -> void:
	p.set(&"_pitch", deg)
	p.head.rotation.x = deg_to_rad(deg)


## Turns the view (standing) to look at `target` over `seconds`.
func face(target: Vector3, seconds: float = 0.9) -> void:
	var eye: Vector3 = p.camera.global_position
	var to := (target - eye).normalized()
	var yaw0: float = p.rotation.y
	var yaw1 := atan2(-to.x, -to.z)
	var pitch0: float = p.get(&"_pitch")
	var pitch1 := rad_to_deg(asin(clampf(to.y, -1, 1)))
	var t := 0.0
	while t < seconds:
		await process_frame
		t += dt()
		var k := smoothstep(0.0, 1.0, t / seconds)
		p.rotation.y = lerp_angle(yaw0, yaw1, k)
		set_pitch(lerpf(pitch0, pitch1, k))


## Walks through waypoints with the real move action (turns first, then walks), eyes level.
func walk(points: Array, run: bool = false, limit_each: float = 40.0) -> void:
	drive_on()
	for target: Vector3 in points:
		var t := 0.0
		var last: Vector3 = p.global_position
		var still := 0.0
		while true:
			var d := Vector3(target.x - p.global_position.x, 0, target.z - p.global_position.z)
			if d.length() < 0.45:
				break
			var want := atan2(-d.x, -d.z)
			p.rotation.y = lerp_angle(p.rotation.y, want, 1.0 - exp(-4.5 * dt()))
			set_pitch(lerpf(p.get(&"_pitch"), -3.0, 1.0 - exp(-3.0 * dt())))
			if absf(angle_difference(p.rotation.y, want)) < deg_to_rad(40):
				Input.action_press("move_forward")
				if run:
					Input.action_press("sprint")
			else:
				Input.action_release("move_forward")
			await process_frame
			t += dt()
			still = still + dt() if p.global_position.distance_to(last) < 0.002 else 0.0
			last = p.global_position
			if t > limit_each or still > 3.0:  # stuck: never ruin a long render
				print(LOG, "stuck near %s, placing at %s" % [p.global_position, target])
				release()
				p.global_position = target + Vector3(0, 0.05, 0)
				p.velocity = Vector3.ZERO
				break
	release()
	await secs(0.35)


func use(path: String) -> void:
	var node: Node = lv.get_node(path)
	var area: Node = node.find_child("Interactable", true, false) if node.name != "Interactable" else node
	area.interact(p)
	await process_frame


func close_note(after: float) -> void:
	await secs(after)
	var notes = lv.get_node("HUD/NoteView")
	if notes.is_open:
		notes.close()
	await secs(0.4)


## Plays out an open conversation at a natural pace: reads each line, picks the first choice.
func converse(limit: float = 90.0) -> void:
	var view = lv.get_node("HUD/DialogueView")
	await until(func() -> bool: return view.is_open, 4.0)
	var t := 0.0
	while view.is_open and t < limit:
		if view.choice_texts().size() > 0:
			await secs(2.4)
			if view.is_open and view.choice_texts().size() > 0:
				view.choose(0)
		elif float(view.get(&"_auto_left")) > 0.0:
			await process_frame
		else:
			await until(func() -> bool: return not view.get(&"_typing") or not view.is_open, 6.0)
			await secs(2.2)
			if view.is_open and view.choice_texts().is_empty() and float(view.get(&"_auto_left")) <= 0.0:
				view.advance()
		await process_frame
		t += 0.1
	await secs(0.5)


func spot(target: Vector3) -> void:
	await face(target, 1.0)
	await secs(0.5)
	var id = get_first_node_in_group("camcorder").try_spot()
	print(LOG, "spotted ", id)
	await secs(2.4)


func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	ev = root.get_node("EventBus")
	game.save_path = "user://tape01_walk_save.json"
	game.delete_save()
	game.mark_intro_seen()
	game.chapter_complete_wait = 60.0
	for path in ["res://ui/menus/boot.tscn", "res://ui/menus/main_menu.tscn", "res://chapters/chapter_01/shanti_vihar.tscn"]:
		load(path)

	# ---- boot + menu, briefly
	mark("boot")
	change_scene_to_file("res://ui/menus/boot.tscn")
	await secs(3.2)
	await secs(2.0)
	current_scene.advance()
	await until(func() -> bool: return current_scene and current_scene.name == "MainMenu")
	var loader = root.get_node("SceneLoader")
	await until(func() -> bool: return not loader.is_transitioning(), 20.0)
	await secs(4.0)
	if not game.start_chapter(&"tape_01_watchman"):
		print(LOG, "could not start Tape 1")
	await until(func() -> bool: return current_scene and current_scene.name == "ShantiVihar" and not loader.is_transitioning(), 60.0)
	lv = current_scene
	mark("tape1")
	drive_on()
	set_pitch(-5.0)
	var story = lv.get_node("Story")
	var stalker = lv.get_node("Stalker/Brain")
	stalker.reload_on_catch = false
	lv.get_node("Deshmukh").speed = 2.4  # his 3:12 walk, a little brisker than life

	# ---- the cabin, 10:40 PM: the opening narration, the register, the CCTV
	await face(Vector3(7.0, 1.0, 25.0), 2.5)
	await secs(3.0)
	await face(Vector3(4.0, 1.4, 23.0), 2.5)
	await secs(2.5)
	await face(Vector3(6.3, 0.8, 24.85), 1.5)
	await walk([Vector3(6.0, 0, 24.1)])
	await face(Vector3(6.3, 0.8, 24.85), 0.8)
	await use("GateRegister")
	await close_note(4.5)
	await secs(3.5)
	await face(Vector3(7.0, 0.95, 25.0), 1.0)
	await use("CCTV")
	await secs(5.0)
	mark("parcel")
	await face(Vector3(6.9, 0.2, 22.4), 1.2)
	await walk([Vector3(6.6, 0, 23.1)])
	await face(Vector3(6.9, 0.15, 22.4), 0.8)
	await use("Parcel")
	await secs(1.5)

	# ---- Mrs. Iyer comes down for her parcel
	await walk([Vector3(5.0, 0, 23.0), Vector3(2.6, 0, 23.0), Vector3(1.8, 0, 21.2)])
	var iyer = lv.get_node("IyerNPC")
	await face(Vector3(3.3, 1.5, 12.0), 1.2)
	await until(func() -> bool: return iyer.global_position.distance_to(Vector3(3.3, 0, 23.4)) < 1.2, 45.0)
	await face(iyer.global_position + Vector3(0, 1.55, 0), 1.0)
	mark("iyer")
	iyer.talk()
	await converse()
	await secs(1.5)

	# ---- the first round: four wings (Deshmukh calls out at B), a figure on D's balcony
	mark("patrol")
	await walk([Vector3(0.5, 0, 15.0), Vector3(-1.0, 0, 2.0), Vector3(-24.0, 0, -8.0), Vector3(-28.5, 0, -12.6)])
	await face(Vector3(-28.5, 3.0, -20.0), 1.2)
	await secs(1.5)
	await walk([Vector3(-16.0, 0, -12.6)])
	var deshmukh = lv.get_node("DeshmukhNPC")
	if deshmukh.active:
		await face(deshmukh.global_position + Vector3(0, 1.55, 0), 1.0)
		await secs(1.5)
		await walk([deshmukh.global_position + (Vector3(-16.0, 0, -12.6) - deshmukh.global_position).normalized() * 1.6])
		await face(deshmukh.global_position + Vector3(0, 1.55, 0), 0.8)
		mark("deshmukh")
		deshmukh.talk()
		await converse()
		await secs(1.0)
	await walk([Vector3(-12.5, 0, -12.6), Vector3(3.5, 0, -12.6)])
	await face(Vector3(3.5, 3.0, -20.0), 1.0)
	await secs(1.0)
	await walk([Vector3(19.5, 0, -12.6)])
	await secs(1.0)
	await walk([Vector3(20.0, 0, 2.0)])
	mark("spot_d")
	await spot(lv.get_node("CamWindowD").global_position + Vector3(0, 1.5, 0))
	# the terraces (top floors): padlocked off camera on the way back
	await walk([Vector3(12.0, 0, 10.0)])
	for letter in "ABCD":
		lv.get_node("Wing%s/TerraceLock/Interactable" % letter).interact(p)
	await walk([Vector3(4.0, 0, 18.0), Vector3(2.6, 0, 23.0), Vector3(5.0, 0, 23.0), Vector3(5.75, 0, 23.6)])

	# ---- the tape cut to 3:10, the register, Deshmukh walks out at 3:12
	mark("cut_3am")
	await until(func() -> bool: return ev.has_fired(&"back_at_cabin"), 5.0)
	await lv.get_node("Camcorder").cut_finished
	await secs(5.0)
	await face(Vector3(6.3, 0.8, 24.85), 1.0)
	await use("GateRegister")
	await close_note(4.0)
	await face(Vector3(3.0, 1.5, 23.0), 1.5)
	mark("deshmukh_walk")
	await until(func() -> bool: return ev.has_fired(&"deshmukh_left"), 60.0)
	await secs(5.0)
	drive_on()
	await face(Vector3(6.3, 0.8, 24.85), 1.0)
	await use("GateRegister")
	await close_note(3.5)
	await face(Vector3(7.0, 0.95, 25.0), 1.0)
	await use("CCTV")
	await until(func() -> bool: return ev.has_fired(&"cctv_deshmukh"), 10.0)
	await secs(3.0)
	lv.get_node("CCTV").show_camera(2, 6.0)
	await secs(1.0)
	mark("spot_cctv")
	await spot(lv.get_node("SpotCCTV").global_position)

	# ---- the empty balcony, the intercom
	await walk([Vector3(5.0, 0, 23.0), Vector3(2.6, 0, 23.0), Vector3(0.5, 0, 15.0), Vector3(-1.0, 0, 2.0), Vector3(-4.5, 0, -4.5)])
	mark("balcony")
	await face(Vector3(-4.25, 13.0, -20.0), 2.0)
	await until(func() -> bool: return ev.has_fired(&"balcony_checked"), 6.0)
	await secs(5.0)
	await until(func() -> bool: return lv.get_node("Intercom").ringing, 10.0)
	await face(Vector3(4.0, 2.0, 22.0), 1.2)
	await walk([Vector3(-1.0, 0, 2.0), Vector3(0.5, 0, 15.0), Vector3(2.6, 0, 23.0), Vector3(5.0, 0, 24.2)], true)
	await face(Vector3(4.12, 1.4, 24.6), 0.8)
	mark("intercom")
	await use("Intercom")
	await secs(16.0)
	await face(Vector3(7.38, 1.5, 23.2), 1.2)
	await walk([Vector3(6.6, 0, 23.3)])
	await face(Vector3(7.38, 1.5, 23.2), 0.6)
	await use("KeyBoard")
	await secs(2.5)

	# ---- (tape cut) flat 4B
	var camcorder = get_first_node_in_group("camcorder")
	camcorder.tape_cut("03:31:20")
	await secs(0.6)
	var door: Node3D = lv.get_node("WingB/Door4B")
	var flat := Vector3(-7.0, 12.05, -16.5)
	var out_dir := (door.global_position - flat)
	out_dir.y = 0
	out_dir = out_dir.normalized()
	p.global_position = door.global_position + out_dir * 1.6 + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(out_dir.x, out_dir.z)
	set_pitch(-2.0)
	await camcorder.cut_finished
	mark("flat4b")
	await secs(1.0)
	await use("WingB/Door4B")
	await secs(1.2)
	await walk([door.global_position - out_dir * 0.8, flat])
	await until(func() -> bool: return ev.has_fired(&"4b_checked"), 5.0)
	await face(Vector3(-7.2, 14.2, -14.1), 2.0)
	await secs(4.0)
	await spot(lv.get_node("Cam4B").global_position + Vector3(0, 1.5, 0))
	await secs(3.0)

	# ---- (tape cut) back at the cabin: the stranger's entries, the secretary, the power cut
	camcorder.tape_cut("03:44:05")
	await secs(0.6)
	p.global_position = Vector3(5.6, 0.05, 23.4)
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(200)
	await camcorder.cut_finished
	mark("register_late")
	await until(func() -> bool: return ev.has_fired(&"cabin_return2"), 5.0)
	await face(Vector3(6.3, 0.8, 24.85), 1.0)
	await use("GateRegister")
	await close_note(7.0)
	await secs(3.0)
	await face(Vector3(5.97, 0.8, 24.85), 1.0)
	mark("phone")
	await use("Phone")
	await converse(120.0)
	await until(func() -> bool: return ev.has_fired(&"secretary_called"), 10.0)
	await secs(7.0)
	p.set_flashlight(true)

	# ---- in the dark: to the meter room (the Cameraman walks the courtyard)
	mark("dark")
	await walk([Vector3(5.0, 0, 23.0), Vector3(2.6, 0, 23.0), Vector3(-1.0, 0, 15.0), Vector3(-1.0, 0, 0.5), Vector3(22.0, 0, 0.5), Vector3(24.6, 0, -3.45)])
	await face(Vector3(26.0, 1.2, -3.45), 0.8)
	await use("MeterDoor")
	await secs(1.2)
	await walk([Vector3(27.6, 0, -3.45), Vector3(28.4, 0, -3.0)])
	await until(func() -> bool: return ev.has_fired(&"meter_room_reached"), 5.0)
	await secs(3.0)
	await face(Vector3(28.6, 1.45, -2.2), 1.0)
	mark("main_switch")
	await use("MainSwitch")

	# ---- the ending -> END OF TAPE
	var found := []
	await until(func() -> bool:
		for c in root.get_children():
			if c is CanvasLayer and c.has_method("is_showing_card") and c.is_showing_card():
				found.append(c)
				return true
		return false, 90.0)
	mark("end_of_tape")
	await secs(5.0)
	mark("end")
	game.delete_save()
	game.save_path = root.get_node("SaveManager").DEFAULT_PATH
	if found.size() > 0:
		found[0].queue_free()
	game.quit_game()
