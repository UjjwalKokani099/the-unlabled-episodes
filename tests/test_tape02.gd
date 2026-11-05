extends SceneTree
# Tape 2, The Toll Booth (first pass, debug chapter tape_02_wip): plays the whole night.
# Radio check-in, three vehicles (toll, receipt, plate in the log, barrier), the log, then
# the white Omni van four times through tape cuts (old driver, young, Salim's uniform; one
# more passenger each pass, Raghu on the fourth), radio calls, the lane camera, a checkpoint
# reload, the line in the log Salim didn't write, and the 3:12 ending -> END OF TAPE -> room.
# Run: <console exe> --path . --quit-after 90000 --script res://tests/test_tape02.gd

var fails := 0
var game: Node
var events: Node
var lv: Node
var p: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func until(cond: Callable, seconds: float = 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func use(path: String) -> void:
	lv.get_node(path + "/Interactable").interact(p)


func talk_through() -> void:
	var dv = lv.get_node("HUD/DialogueView")
	await until(func() -> bool: return dv.is_open, 3.0)
	while dv.is_open:
		if dv.choice_texts().size() > 0:
			dv.choose(0)
		else:
			dv.advance()
		await frames(2)


func close_note() -> void:
	var note = lv.get_node("HUD/NoteView")
	await frames(2)
	if note.has_method("close"):
		note.close()
	await frames(2)


func serve(v) -> bool:
	if not await until(func() -> bool: return v.is_waiting(), 25.0):
		return false
	use("TollWindow")
	await frames(2)
	use("BarrierButton")
	return await until(func() -> bool: return not v.visible, 25.0)


func setup_level() -> void:
	lv = current_scene
	p = get_first_node_in_group("player")
	var story = lv.get_node("Story")
	story.time_scale = 0.05
	lv.get_node("HUD/DialogueView").instant = true


func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	events = root.get_node("EventBus")
	game.save_path = "user://test_tape02_save.json"
	game.delete_save()
	game.chapter_complete_wait = 0.3
	check(game.start_chapter(&"tape_02_wip"), "Tape 2 (WIP) starts from the debug chapter list")
	await game.transition_finished
	setup_level()
	check(lv.name == "TollPlaza", "the toll plaza loads")
	var camcorder = get_first_node_in_group("camcorder")
	check(camcorder.osd.clock_text().begins_with("01:0"), "camcorder clock starts at 1:05 AM (%s)" % camcorder.osd.clock_text())
	var objectives = root.get_node("ObjectiveManager")
	check(objectives.is_active(&"radio_checkin"), "first: check in on the radio")

	# ---- routine: radio, three vehicles, the log
	use("Radio")
	await talk_through()
	check(events.has_fired(&"radio_checkin"), "radio check-in with control")
	var names := ["Car1", "Tempo", "Car2"]
	for i in 3:
		var v = lv.get_node("Vehicles/" + names[i])
		check(await serve(v), "%s served: toll, barrier, gone" % names[i])
	check(events.count(&"vehicle_served") == 3, "three vehicles served")
	var log_text: String = lv.get_node("PlateLog").page()
	check(log_text.contains("MH 12 KT 4471") and log_text.contains("GJ 05 CR 2208"), "their plates are in Salim's log")
	use("PlateLog")
	await close_note()
	check(events.has_fired(&"log_written"), "the hour written up")

	# ---- the van, four times
	var van = lv.get_node("Vehicles/Van")
	check(await until(func() -> bool: return van.visible, 30.0), "after a tape cut, the van comes")
	check(camcorder.osd.clock_text().begins_with("01:5"), "the clock jumped to ~1:52 (%s)" % camcorder.osd.clock_text())
	check(van.get_node("DriverOld").visible and van.get_node("Passengers/P1").visible and not van.get_node("Passengers/P2").visible,
		"pass 1: an old driver, one passenger")
	check(await serve(van), "pass 1 served")
	check(lv.get_node("PlateLog").page().contains("MH 04 AX 0312"), "the van's plate is logged")
	use("Radio")
	await talk_through()
	check(events.has_fired(&"radio_van"), "radio: control saw nothing on the lane camera")
	check(await until(func() -> bool: return van.visible, 30.0), "pass 2 comes")
	check(van.get_node("DriverYoung").visible and van.get_node("Passengers/P2").visible, "pass 2: a young driver, two passengers")

	# checkpoint reload mid-night: the van comes back as it was
	check(game.saved_checkpoint_id() == &"booth", "a checkpoint after the tape cut")
	check(game.load_checkpoint(), "reload the checkpoint")
	await until(func() -> bool: return current_scene != lv and current_scene != null and current_scene.name == "TollPlaza", 30.0)
	await frames(3)
	setup_level()
	camcorder = get_first_node_in_group("camcorder")
	van = lv.get_node("Vehicles/Van")
	check(await until(func() -> bool: return van.visible, 30.0) and van.get_node("DriverYoung").visible,
		"after the reload pass 2 comes again (young driver)")
	check(events.count(&"vehicle_served") == 3 and events.has_fired(&"van_served_1"), "earlier passes stay done")
	check(await serve(van), "pass 2 served")
	use("CCTV")
	check(await until(func() -> bool: return events.has_fired(&"lane_checked"), 10.0), "the lane camera: someone at the far end")
	check(await until(func() -> bool: return van.visible, 30.0), "pass 3 comes")
	check(van.get_node("DriverUniform").visible and van.get_node("Passengers/P3").visible and lv.get_node("CamRoad").active,
		"pass 3: Salim's uniform, three passengers, a figure on the road")
	check(await serve(van), "pass 3 served")
	use("Radio")
	await talk_through()
	check(events.has_fired(&"radio_dead"), "radio: no control, a voice")
	check(await until(func() -> bool: return van.visible, 30.0), "pass 4 comes")
	check(van.get_node("Passengers/Raghu").visible, "pass 4: Raghu in the back")
	check(await serve(van), "pass 4 served")
	use("PlateLog")
	await close_note()
	check(events.has_fired(&"log_read_late") and lv.get_node("PlateLog").page().contains("S. KHAN"),
		"the log holds a line Salim didn't write")

	# ---- 3:12: the van stops and doesn't move
	check(await until(func() -> bool: return van.is_waiting(), 40.0), "the van stops at the window")
	check(camcorder.osd.clock_text().begins_with("03:1"), "3:1x AM (%s)" % camcorder.osd.clock_text())
	use("TollWindow")
	check(await until(func() -> bool: return lv.get_node("Story").ending_started, 3.0), "taking the toll starts the ending")
	check(await until(func() -> bool: return not lv.get_node("Power").powered, 10.0), "the booth lights die")
	check(await until(func() -> bool: return lv.get_node("Vehicles/Van/CamBackseat").active, 10.0), "a red dot in the back seat")
	await until(func() -> bool: return current_scene != null and current_scene.name == "Hub", 60.0)
	check(game.is_completed(&"tape_02_wip") and current_scene.name == "Hub", "END OF TAPE, back in the room")
	var unscripted = load("res://tests/support.gd").unscripted_voice_ids(self)
	check(unscripted.is_empty(), "every spoken line is in the voice script %s" % [unscripted])
	game.delete_save()
	await load("res://tests/support.gd").finish(self, fails)
