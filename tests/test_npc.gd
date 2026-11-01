extends SceneTree
# Phase 4: dialogue files (branches, conditions, flags, events), the dialogue box, the NPC
# base (navmesh walking, uncanny head tracking, talking), and Tape 1's people: Mrs. Iyer's
# parcel errand, Mr. Deshmukh's 3:12 request, and the secretary's call remembering both.
# Separate save file. Run: <console exe> --path . --quit-after 60000 --script res://tests/test_npc.gd

var fails := 0
var events: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func until(cond: Callable, timeout: float = 15.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await create_timer(0.05).timeout
		t += 0.05
	return cond.call()


## Talks through the open conversation, picking choices whose text contains one of `picks`
## (else the first). Returns the ids of the lines shown.
func run_dialogue(view, picks: Array = []) -> Array:
	var seen: Array = []
	var guard := 0
	while view.is_open and guard < 60:
		guard += 1
		if seen.is_empty() or seen[-1] != view.current_id:
			seen.append(view.current_id)
		var texts: PackedStringArray = view.choice_texts()
		if texts.is_empty():
			view.advance()
		else:
			var index := 0
			for i in texts.size():
				for p: String in picks:
					if texts[i].contains(p):
						index = i
			view.choose(index)
		await physics(1)
	return seen


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	events = root.get_node("Events")
	var obj: Node = root.get_node("Objectives")
	game.save_path = "user://test_save.json"
	game.delete_save()

	# --- Dialogue rules (no level needed) ---
	var D = load("res://scripts/dialogue/dialogue.gd")
	var iyer_d = D.load_file("res://dialogue/tape01/iyer.json")
	check(iyer_d != null and iyer_d.resolve(iyer_d.start) == "hello", "iyer.json loads; first meeting branches to hello")
	check(not D.check("event:parcel_2c") and D.check("!event:parcel_2c"), "event conditions + negation")
	D.set_flag("x_test", true)
	check(D.check("flag:x_test") and D.check(["flag:x_test", "!flag:nope"]), "flag conditions, lists must all hold")
	check(iyer_d.choices("ask_choices").size() == 2, "without the parcel: 'find it' + 'Kishan?' (no 'here it is')")
	for f in ["res://dialogue/tape01/deshmukh.json", "res://dialogue/tape01/secretary.json"]:
		var d = D.load_file(f)
		var broken := []
		for id: String in d.nodes:
			var n: Dictionary = d.nodes[id]
			var targets := [n.get("next", "")]
			for c in n.get("choices", []) + n.get("branch", []):
				targets.append(c.get("next", ""))
			for t: String in targets:
				if t != "" and not d.nodes.has(t):
					broken.append("%s->%s" % [id, t])
		check(broken.is_empty(), "%s: every next/choice/branch points at a real node %s" % [f.get_file(), broken])

	# --- Tape 1 ---
	check(game.start_chapter(&"tape_01_watchman"), "tape 1 starts")
	await game.transition_finished
	var lv: Node = current_scene
	var p = get_first_node_in_group("player")
	var story = lv.get_node("Story")
	story.time_scale = 0.02
	var view = lv.get_node("HUD/DialogueView")
	view.instant = true
	check(await until(func() -> bool: return lv.get_node("Navigation").is_baked), "navmesh baked at load")
	await physics(4)

	# Mr. Deshmukh under B wing: body to the gate, head turns way round to follow you.
	var desh = lv.get_node("DeshmukhNPC")
	check(desh.active and desh.uncanny, "Mr. Deshmukh is waiting under B wing")
	p.global_position = desh.global_position + Vector3(1.4, 0.05, -2.6)  # behind him, clear of his way in
	await create_timer(0.6).timeout
	check(absf(desh.head_yaw_deg()) > 100.0, "his head turns %.0f degrees to watch you (body still to the gate)" % desh.head_yaw_deg())
	desh.get_node("Talk").interact(p)
	await physics(2)
	check(view.is_open and not p.input_enabled, "talking opens the dialogue box, player still")
	var seen: Array = await run_dialogue(view, ["How do you know", "Of course"])
	check("name" in seen and "promise" in seen, "branch: how he knows your name, then the promise (%s)" % [seen])
	check(D.flag("promised_gate") == true and D.flag("deshmukh_knew_name") == true, "choices set flags")
	check(not view.is_open and p.input_enabled, "dialogue ends, player free")
	desh.walk_speed = 6.0
	check(await until(func() -> bool: return not desh.active), "he walks back into the B wing stairwell and is gone")

	# Mrs. Iyer comes down after the first CCTV check.
	p.global_position = Vector3(5.75, 0.05, 23.6)
	await physics(4)
	lv.get_node("GateRegister/Interactable").interact(p)
	lv.get_node("HUD/NoteView").close()
	var iyer = lv.get_node("IyerNPC")
	iyer.walk_speed = 9.0
	lv.get_node("CCTV/Interactable").interact(p)
	await physics(2)
	check(iyer.active and obj.is_active(&"give_parcel"), "Mrs. Iyer appears; objective: give her the parcel")
	check(await until(func() -> bool: return iyer.global_position.distance_to(story.IYER_WAIT) < 0.6, 20.0),
		"she walks from C wing to the cabin door by the navmesh (%.1f m off)" % iyer.global_position.distance_to(story.IYER_WAIT))
	iyer.get_node("Talk").interact(p)
	await physics(2)
	seen = await run_dialogue(view, ["find it"])
	check("find" in seen, "no parcel yet: she tells you where Kishan kept them")
	lv.get_node("Parcel/Interactable").interact(p)
	await physics(2)
	iyer.get_node("Talk").interact(p)
	await physics(2)
	seen = await run_dialogue(view, ["Here it is", "I'll check"])
	check(events.has_fired(&"parcel_given") and obj.is_completed(&"give_parcel"), "parcel given, objective done")
	check("redlight" in seen and D.flag("promised_iyer") == true and D.flag("heard_terrace") == true, "she mentions the red light on D wing terrace")
	check(await until(func() -> bool: return not iyer.active, 20.0), "she walks home to C wing")

	# The night: 3:12 remembers the promise; the secretary remembers both.
	for e in [&"patrol_point", &"patrol_point", &"patrol_point", &"patrol_point",
			&"terrace_locked", &"terrace_locked", &"terrace_locked", &"terrace_locked"]:
		events.fire(e)
	await physics(2)
	events.fire(&"back_at_cabin")
	await lv.get_node("Camcorder").cut_finished
	lv.get_node("Deshmukh").speed = 40.0
	lv.get_node("GateRegister/Interactable").interact(p)
	lv.get_node("HUD/NoteView").close()
	check(await until(func() -> bool: return events.has_fired(&"deshmukh_at_gate")), "3:12: he walks out")
	await physics(2)
	var sub: String = lv.get_node("HUD/Subtitles").current_text()
	check(sub.contains("I kept it open"), "Raghu's line remembers the promise ('%s')" % sub)
	check(await until(func() -> bool: return events.has_fired(&"deshmukh_left")), "...and is gone")
	for e in [&"deshmukh_logged", &"cctv_deshmukh", &"balcony_checked", &"intercom_answered", &"key_4b",
			&"4b_checked", &"cabin_return2", &"register_read_late"]:
		events.fire(e)
	await physics(2)
	check(obj.is_active(&"call_secretary"), "objective: phone the secretary")
	lv.get_node("Phone/Interactable").interact(p)
	check(await until(func() -> bool: return view.is_open), "the secretary picks up (dialogue)")
	var call_seen: Array = await run_dialogue(view, ["Mrs. Iyer says"])
	check("promised" in call_seen, "secretary: 'You let him out? Kishan said the same thing.'")
	check("iyer" in call_seen, "the Mrs. Iyer choice appears because she told you about the light")
	check(await until(func() -> bool: return events.has_fired(&"power_cut") and events.has_fired(&"secretary_called")),
		"the line goes dead, the power cuts")

	game.delete_save()
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
