extends SceneTree
# Nikhil's phone (studio spec 5/6, build step 6b), in the hub: take it from the desk, raise
# it (R), the live screen (time, battery, apps) on the 3D model, Messages -> Maa -> reply
# completes the chore, torch, charger takes it and gives it back (battery rises), an incoming
# call rings and plays its dialogue, stage-gated call log (3:12 missed call from stage 2),
# taps on the glass, the world can't be used while it's up. Tape 1 has no phone.
# Run: <console exe> --path . --quit-after 9000 --script res://tests/test_phone.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func press(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(2)


func _initialize() -> void:
	await process_frame
	var game = root.get_node("GameManager")
	var events = root.get_node("EventBus")
	var objectives = root.get_node("ObjectiveManager")
	game.save_path = "user://test_save.json"
	game.delete_save()
	game.mark_intro_seen()
	game.enter_hub()
	await game.transition_finished
	await frames(10)
	var hub: Node = current_scene
	var p = get_first_node_in_group("player")
	var phone = p.phone
	check(phone != null and not phone.carried, "the phone lies on the desk")
	await press(&"phone")
	check(not phone.is_raised(), "can't raise a phone you haven't picked up")
	hub.take_phone()
	check(phone.carried and not hub.room.get_node("Phone").visible and events.has_fired(&"took_phone"), "took the phone")
	await press(&"phone")
	await create_timer(0.5).timeout
	check(phone.is_raised() and phone.visible, "R raises it")
	check(p.is_using_phone() and not p.interactor._can_act(), "the world can't be used while it's up")
	var scr = phone.screen
	check(scr.page == "home" and scr.row_texts().size() >= 3, "home screen: %s" % [scr.row_texts()])
	check(scr._time.text.length() >= 4 and scr._status.text.contains("%"), "status bar: time + battery ('%s', '%s')" % [scr._time.text, scr._status.text])
	var uv: Vector2 = phone.screen_uv_at(p.camera.unproject_position(phone._screen_quad.global_position))
	check(absf(uv.x - 0.5) < 0.05 and absf(uv.y - 0.5) < 0.05, "screen is a real surface in front of the camera (uv %s)" % uv)

	# --- Messages -> Maa -> reply
	scr.show_page("messages")
	check(scr.row_texts()[0].contains("Maa"), "Messages lists Maa first (%s)" % [scr.row_texts()])
	scr.select()
	await frames(2)
	check(scr.page == "thread" and scr.page_arg == "maa" and scr.row_texts()[0].begins_with("Reply"), "Maa's thread with a reply")
	await press(&"interact")
	check(events.has_fired(&"replied_maa") and objectives.is_completed(&"maa"), "reply sent: the chore is done")
	await press(&"interact")
	check(scr.row_texts().is_empty(), "no second reply")
	# back with right click / Backspace
	var bs := InputEventKey.new()
	bs.physical_keycode = KEY_BACKSPACE
	bs.pressed = true
	Input.parse_input_event(bs)
	await frames(2)
	check(scr.page == "messages", "Backspace goes back")

	# --- torch
	scr.show_page("home")
	var torch_index := -1
	for i in scr.row_texts().size():
		if scr.row_texts()[i].begins_with("Torch"):
			torch_index = i
	var light_before: bool = p.flashlight.visible
	scr.selected = torch_index
	scr.select()
	await frames(2)
	check(p.flashlight.visible != light_before and scr.torch_on == p.flashlight.visible, "torch toggles the light")

	# --- lower, charge, take back
	await press(&"phone")
	await create_timer(0.5).timeout
	check(not phone.is_raised() and not phone.visible, "R lowers it")
	var before: float = scr.battery
	hub.charge_phone()
	check(not phone.carried and phone.charging and hub.room.get_node("Phone").visible and objectives.is_completed(&"charge"),
		"on the charger: chore done")
	phone._process(30.0)
	check(scr.battery > before, "battery charges (%.2f -> %.2f)" % [before, scr.battery])
	hub.take_phone()
	check(phone.carried and not phone.charging, "taken back off the charger")

	# --- incoming call
	game.set_flag("dlg_asked_maa_night", null)
	phone._arrive({"kind": "call", "contact": "maa", "dialogue": "res://data/dialogue/hub/maa_call.json"})
	check(scr.is_ringing() and phone._ring.playing, "a call rings")
	await press(&"phone")
	await create_timer(0.4).timeout
	check(scr.page == "incoming" and scr.row_texts()[0] == "Answer", "incoming call screen")
	var view = hub.get_node("HUD/DialogueView") if hub.has_node("HUD/DialogueView") else get_first_node_in_group("hud").get_node("DialogueView")
	view.instant = true
	scr.select()
	await frames(3)
	check(view.is_open and scr.page == "in_call" and not phone._ring.playing, "answered: Maa talks, the ring stops")
	var guard := 0
	while view.is_open and guard < 200:
		guard += 1
		if view.choice_texts().size() > 0:
			view.choose(1)
		await create_timer(0.1).timeout
	check(events.has_fired(&"maa_called") and scr.page == "home", "the call ends (and was in the call log)")

	# --- stage gating
	var d: Dictionary = scr.load_data("res://data/phone/hub.json", 2)
	var unknown: Array = scr.calls.filter(func(c): return c.contact == "unknown")
	check(unknown.size() == 1 and unknown[0].when.contains("3:12"), "stage 2: a missed call at 3:12 AM from Unknown")
	scr.load_data("res://data/phone/hub.json", 0)
	check(scr.calls.filter(func(c): return c.contact == "unknown").is_empty(), "stage 0: no such call")

	# --- Tape 1 has no phone
	game.start_chapter(&"tape_00_test")
	await game.transition_finished
	check(get_first_node_in_group("player").phone == null, "test tape: no phone")

	game.delete_save()
	game.save_path = root.get_node("SaveManager").DEFAULT_PATH
	current_scene.queue_free()
	await frames(3)
	print("RESULT fails=%d" % fails)
	quit()
