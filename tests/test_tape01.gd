extends SceneTree
# Tape 1 (Shanti Vihar), the whole night: Raghu's first round, the tape cut to 3 AM,
# Deshmukh walking out at 3:12, the CCTV-only balcony figure, the intercom, flat 4B, the
# stranger's register entries, the secretary's call + power cut (and a checkpoint reload
# in the dark), spotting the Cameraman's three appearances, the ending -> hub stage 1.
# Separate save file. Run: <console exe> --path . --quit-after 60000 --script res://tests/test_tape01.gd

var fails := 0
var game: Node
var events: Node
var obj: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## Waits (real time) until an Events id has fired.
func wait_event(id: StringName, timeout: float = 10.0) -> bool:
	var t := 0.0
	while not events.has_fired(id) and t < timeout:
		await wait(0.05)
		t += 0.05
	return events.has_fired(id)


## Waits (real time) until `cond` returns true.
func until(cond: Callable, timeout: float = 10.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await wait(0.05)
		t += 0.05
	return cond.call()


func goto(p, pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await physics(6)


func use(lv: Node, path: String, p) -> void:
	lv.get_node(path + "/Interactable").interact(p)
	await physics(2)
	var notes = lv.get_node("HUD/NoteView")
	if notes.is_open:
		notes.close()


## Points the player's camera at `target` and presses Spot.
func spot_at(target: Vector3) -> StringName:
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	cam.look_at(target)
	var camcorder = get_first_node_in_group("camcorder")
	var id: StringName = camcorder.try_spot()
	await wait(1.9)  # the freeze-frame
	return id


func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	obj = root.get_node("ObjectiveManager")
	events = root.get_node("EventBus")
	game.save_path = "user://test_save.json"
	game.delete_save()
	check(game.start_chapter(&"tape_01_watchman"), "tape 1 is built and starts")
	await game.transition_finished
	var lv: Node = current_scene
	var p = get_first_node_in_group("player")
	var story = lv.get_node("Story")
	story.time_scale = 0.02
	await physics(10)
	var osd = lv.get_node("Camcorder").osd
	check(lv.get_node("Static").merged_into < 400, "6000+ boxes batched into %d meshes" % lv.get_node("Static").merged_into)
	check(osd.get_node("Date").text == "MAR. 14 1998", "camcorder date 14 Mar 1998")
	check(game.saved_checkpoint_id() == &"start", "start checkpoint in the cabin")
	check(p.get_node("Head/Camera3D").cull_mask & (1 << 19) == 0, "player's eyes can't see CCTV-only things")

	# ---- act 1: the first round
	await use(lv, "GateRegister", p)
	await use(lv, "CCTV", p)
	check(obj.is_completed(&"sign_register") and obj.is_completed(&"check_cctv"), "register signed, CCTV checked")

	# spot #1: a figure on D wing's lit balcony during the round
	check(lv.get_node("CamWindowD").active, "someone stands on D wing's 3rd-floor balcony")
	await goto(p, Vector3(20, 0.05, 2))
	check(await spot_at(lv.get_node("CamWindowD").global_position + Vector3(0, 1.5, 0)) == &"t1_d_balcony", "spotted him on D wing's balcony")
	for letter in "ABCD":
		await goto(p, lv.get_node("Wing%s/Patrol" % letter).global_position - Vector3(0, 1, 0))
	check(obj.is_completed(&"patrol"), "patrolled the four wings")
	for letter in "ABCD":
		lv.get_node("Wing%s/TerraceLock/Interactable" % letter).interact(p)
	await physics(2)
	check(obj.is_completed(&"lock_terraces") and lv.get_node("WingA/TerraceDoor").locked, "terrace doors padlocked")
	check(lv.get_node("WingB/Door4B").locked, "4B locked")

	# ---- the tape cut to 3 AM
	await goto(p, Vector3(5.75, 0.05, 23.6))
	check(events.has_fired(&"back_at_cabin"), "back at the cabin ends the round")
	await lv.get_node("Camcorder").cut_finished
	await process_frame  # the director also awaits cut_finished, then moves the stool
	check(osd.clock_text().begins_with("03:1") and osd.clock_text().ends_with("AM"), "tape cut: clock now %s" % osd.clock_text())
	check(obj.is_active(&"sign_3am"), "objective: the 3 AM register entry")
	check(lv.get_node("Stool").position.distance_to(Vector3(5.3, 0, 24.4)) > 1.0, "the stool has moved into the doorway")

	# ---- 3:12: Deshmukh walks out
	lv.get_node("Deshmukh").speed = 40.0
	await use(lv, "GateRegister", p)
	var wicket_max := 0.0
	var t := 0.0
	while not events.has_fired(&"deshmukh_left") and t < 10.0:
		await physics(1)
		t += 1.0 / 60.0
		wicket_max = maxf(wicket_max, lv.get_node("Wicket").rotation_degrees.y)
	check(events.has_fired(&"deshmukh_left"), "Mr. Deshmukh walked out of the gate")
	check(wicket_max > 1.0, "the wicket gate swung open for him")
	check(lv.get_node("BalconyDeshmukh").visible and lv.get_node("BalconyDeshmukh/Body/Body/Mesh").find_children("*", "MeshInstance3D", true, false)[0].layers == 1 << 19,
		"...and now stands on his balcony, on CCTV only")
	check(await until(func() -> bool: return not lv.get_node("Deshmukh").visible), "he never comes back in")
	await use(lv, "GateRegister", p)
	check(obj.is_completed(&"log_deshmukh") and lv.get_node("GateRegister").page().contains("03:12 AM"), "Deshmukh's exit logged at 03:12")
	await use(lv, "CCTV", p)
	check(lv.get_node("CCTV").current == 1, "CCTV jumps to the B Wing feed")
	check(await wait_event(&"cctv_deshmukh"), "seen him on the CCTV")

	# spot #1: the Cameraman on the B stairs feed
	lv.get_node("CCTV").show_camera(2, 5.0)
	await physics(2)
	check(await spot_at(lv.get_node("SpotCCTV").global_position) == &"t1_cctv_stairs", "spotted him on CAM 3 (B stairs)")
	check(game.is_spotted(&"t1_cctv_stairs") and not paused, "spot remembered; tape unpaused")

	# ---- the empty balcony, the intercom
	await goto(p, Vector3(-5, 0.05, -7))
	check(events.has_fired(&"balcony_checked"), "looked up at the 4B balcony")
	await wait(0.3)
	check(lv.get_node("Intercom").ringing, "the 4B intercom rings")
	await use(lv, "Intercom", p)
	check(obj.is_completed(&"answer_intercom"), "answered: only breathing")
	check(await until(func() -> bool: return lv.get_node("Cam4B").active), "someone is waiting in 4B")
	await use(lv, "KeyBoard", p)
	check(not lv.get_node("WingB/Door4B").locked, "spare key unlocks 4B")

	# ---- flat 4B (spot #2 in the bedroom doorway)
	await goto(p, Vector3(-7, 12.05, -16.5))
	check(events.has_fired(&"4b_checked"), "checked flat 4B")
	await goto(p, Vector3(-4.25, 12.05, -16.0))
	check(await spot_at(lv.get_node("Cam4B").global_position + Vector3(0, 1.5, 0)) == &"t1_flat_4b", "spotted him in 4B's doorway")
	await physics(3)

	# ---- back at the cabin: the stranger's entries
	await goto(p, Vector3(5.75, 0.05, 23.6))
	check(events.has_fired(&"cabin_return2"), "back at the cabin")
	await use(lv, "GateRegister", p)
	var page: String = lv.get_node("GateRegister").page()
	check(obj.is_completed(&"read_register") and page.contains("Raghu is reading this.") and page.contains("Raghu went into 4B."),
		"the register logs Raghu's own movements in another hand")

	# ---- the secretary, the power cut
	await use(lv, "Phone", p)
	var view = lv.get_node("HUD/DialogueView")
	view.instant = true
	check(await until(func() -> bool: return view.is_open), "the secretary picks up")
	var guard := 0
	while view.is_open and guard < 40:  # first choice each time
		guard += 1
		if view.choice_texts().is_empty():
			view.advance()
		else:
			view.choose(0)
		await physics(1)
	check(await wait_event(&"secretary_called"), "phoned the secretary: 4B empty for eight months")
	check(not lv.get_node("Power").powered and not lv.get_node("CabinTube").on, "power cut: the lights are out")
	check(load("res://assets/materials/glass_lit_warm.tres").emission_energy_multiplier == 0.0, "lit windows went dark")
	await wait(0.4)  # the director saves a checkpoint after the call

	# ---- checkpoint reload in the dark
	check(game.load_checkpoint(), "reload the checkpoint during the power cut")
	await game.transition_finished
	lv = current_scene
	p = get_first_node_in_group("player")
	story = lv.get_node("Story")
	story.time_scale = 0.02
	await physics(4)
	osd = lv.get_node("Camcorder").osd
	check(not lv.get_node("Power").powered and not lv.get_node("CabinTube").on, "after reload: still no power")
	check(osd.clock_text().begins_with("03:"), "after reload: clock still %s" % osd.clock_text())
	check(obj.is_active(&"meter_room") and lv.get_node("BalconyDeshmukh").visible, "after reload: objective + balcony figure kept")
	var stalker = lv.get_node("Stalker/Brain")
	check(lv.get_node("MainSwitch/Interactable").enabled and await until(func() -> bool: return stalker.state == 4),
		"after reload: switch usable, the Cameraman patrols the courtyard")
	check(game.spotted_count("t1_") == 3, "all three Tape 1 appearances spotted")
	stalker.reload_on_catch = false  # the test teleports through his patrol

	# ---- the meter room, the ending
	await goto(p, Vector3(28.4, 0.05, -3.2))
	check(events.has_fired(&"meter_room_reached"), "reached the meter room")
	check(stalker.state == 0, "the stalk ends at the meter room")
	lv.get_node("MainSwitch/Interactable").interact(p)
	await wait(0.2)
	check(lv.get_node("Power").powered, "main switch: the power is back")
	check(lv.get_node("RaghuStandIn").visible and lv.get_node("CamEnding").active, "last CCTV frame: Raghu, and behind him the red dot")
	await game.transition_finished
	check(game.is_completed(&"tape_01_watchman") and current_scene.name == "Hub", "tape 1 complete, back in the hub")
	check(current_scene.stage == 1, "hub moves to stage 1 (the diary entry)")
	check(load("res://assets/materials/glass_lit_warm.tres").emission_energy_multiplier > 0.0, "window glow restored for other levels")
	check(game.spotted_count("t1_") == 3, "spots survive finishing the tape")
	game.delete_save()
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
