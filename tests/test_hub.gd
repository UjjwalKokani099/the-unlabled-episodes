extends SceneTree
# Nikhil's room: box hands out unlabeled tapes in order, VCR plays/resumes, chores fire
# objectives, story stages switch on the bible's room changes. Uses a separate save file.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_hub.gd

var fails := 0
var game: Node

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func message() -> String:
	return current_scene.get_node("HUD/Message").text

func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	game.chapter_complete_wait = 0.3  # the END OF TAPE card closes itself once black
	var objectives: Node = root.get_node("ObjectiveManager")
	game.save_path = "user://test_save.json"
	game.delete_save()
	change_scene_to_file("res://chapters/hub/hub.tscn")
	await scene_changed
	await frames(10)
	var hub: Node = current_scene

	# --- Stage 0 room ---
	check(hub.stage == 0, "fresh save: stage 0")
	var main_tapes: Array = hub._box_tapes.filter(func(t): return t.chapter_id != &"tape_00_test")
	check(main_tapes.size() == 4, "box holds the four tapes he bought (%d)" % main_tapes.size())
	check(main_tapes.all(func(t): return t.label.text == ""), "every tape is unlabeled")
	check(not hub.room.get_node("Van").visible and not hub.room.get_node("DeliveryBag").visible, "no van, no bag yet")

	# --- Box + VCR ---
	check(hub.box_prompt() == "Take the next tape", "box prompt")
	hub.use_box()
	check(hub.held != null and hub.held.chapter_id == &"tape_01_watchman", "box gives tape 1 first")
	check(hub.vcr_prompt() == "Play the tape", "VCR prompt while holding")
	hub.use_vcr()
	if hub.held.chapter.is_built():
		check(hub.busy, "tape 1 starts playing")
		await game.transition_finished
		game.return_to_hub()
		await game.transition_finished
		hub = current_scene
		await frames(5)
	else:
		await create_timer(3.0).timeout
		check(hub.get_node_or_null("DemoEnd") != null, "unbuilt tape: end-of-demo card")
		hub.get_node("DemoEnd").close()
		await frames(2)
		hub.use_box()
		check(hub.held == null, "using the box again puts the tape back")

	# --- Chores ---
	hub.eat_dinner()
	hub.take_phone()  # replying to Maa happens on the phone now (Messages > Maa > Reply)
	hub.phone.screen.show_page("thread", "maa")
	hub.phone.screen.select()
	hub.charge_phone()
	await frames(2)
	check(objectives.is_completed(&"eat") and objectives.is_completed(&"maa") and objectives.is_completed(&"charge"), "chores completed")
	check(hub.room.get_node("Phone").global_position.distance_to(hub.room.get_node("ChargingSpot").global_position) < 0.01, "phone moved to the charger")

	# --- Story stages ---
	hub.stage = 4
	hub.apply_stage()
	await frames(2)
	main_tapes = hub._box_tapes.filter(func(t): return t.chapter_id != &"tape_00_test")
	check(main_tapes.size() == 5, "after tape 4 the box holds a fifth tape")
	check(hub.room.get_node("Van").visible and hub.room.get_node("DeliveryBag").visible, "van and delivery bag appear")
	check(hub._scratch != null and hub._scratch.text == "108", "108 scratched inside the door")
	hub.read_diary()
	var note: String = hub.get_node("HUD/NoteView/Root/Paper/Margin/Text").text
	check(note.contains("3:12 AM, out."), "diary has the entry he didn't write")
	hub.get_node("HUD/NoteView").close()

	# --- Test tape plays from the hub (debug builds) ---
	var test_tape = hub.room.get_node_or_null("TestTape")
	check(test_tape != null, "test tape on the desk in debug builds")
	hub.pick_up(test_tape)
	hub.use_vcr()
	await game.transition_finished
	check(current_scene.name == "TestRoom", "test tape plays")
	game.complete_chapter()
	await game.transition_finished
	check(current_scene.name == "Hub" and current_scene.stage == 0, "back in the hub; test tape doesn't advance the story")

	game.delete_save()
	await load("res://tests/support.gd").finish(self, fails)
