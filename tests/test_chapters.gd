extends SceneTree
# Chapter flow: start (tape card), checkpoint save, reload restores state without replaying
# scares, completion unlocks/saves and returns to the hub. Uses a separate save file.
# Run: <console exe> --path . --quit-after 6000 --script res://tests/test_chapters.gd

var fails := 0
var game: Node
var events: Node
var objectives: Node

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func physics(n: int) -> void:
	for i in n:
		await physics_frame

func player():
	return root.get_tree().get_first_node_in_group("player")

func active_ids() -> Array:
	return objectives.get_active().map(func(o): return String(o.id))

func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	events = root.get_node("EventBus")
	objectives = root.get_node("ObjectiveManager")
	game.save_path = "user://test_save.json"
	game.delete_save()

	# --- Unlocking ---
	check(game.is_unlocked(&"tape_01_watchman") and not game.is_unlocked(&"tape_02_tollbooth"), "only tape 01 unlocked on a new save")
	check(not game.start_chapter(&"tape_02_tollbooth"), "unbuilt chapter refuses to start")
	check(not game.has_checkpoint(), "no checkpoint on a new save")

	# --- Start ---
	check(game.start_chapter(&"tape_00_test"), "test chapter starts")
	check(paused and game.is_transitioning(), "game paused behind the tape card")
	await game.transition_finished
	var room: Node = current_scene
	check(room != null and room.name == "TestRoom" and not paused, "test room loaded and unpaused")
	check(game.current_chapter.id == &"tape_00_test", "current chapter set")
	await physics(10)
	check(game.saved_checkpoint_id() == &"start", "spawn checkpoint saved (%s)" % game.saved_checkpoint_id())

	# --- Progress, then a checkpoint ---
	var p = player()
	room.get_node("VHSTape").interactable.interact(p)
	room.get_node("LockedDoor").open_away_from(Vector3(8, 0, -11))
	await physics(2)
	room.get_node("Battery1").interactable.interact(p)
	room.get_node("Battery2").interactable.interact(p)
	await physics(2)
	check(active_ids() == ["collect_batteries"] and objectives.get_progress(&"collect_batteries") == 2, "progress before checkpoint (%s)" % [active_ids()])
	p.global_position = Vector3(8, 0, -9.5)
	await physics(6)
	check(game.saved_checkpoint_id() == &"storage", "storage checkpoint saved")
	var dark_count: int = events.count(&"entered_dark_room")
	check(dark_count == 1, "dark room zone fired once on the way")
	var save_text := FileAccess.get_file_as_string("user://test_save.json")
	check(save_text.contains("\"storage\"") and save_text.contains("picked:Battery2"), "checkpoint written to the save file")

	# Do more after the checkpoint (loading must undo this)
	room.get_node("Battery3").interactable.interact(p)
	await physics(2)
	check(active_ids() == ["return_to_start"], "third battery done before reload")

	# --- Load checkpoint ---
	check(game.load_checkpoint(), "load_checkpoint starts")
	await game.transition_finished
	var room2: Node = current_scene
	check(room2 != room and is_instance_valid(room2), "level reloaded")
	await physics(3)
	check(not room2.has_node("VHSTape") and not room2.has_node("Battery1") and not room2.has_node("Battery2"), "picked-up items stay gone")
	check(room2.has_node("Battery3"), "item picked after the checkpoint is back")
	check(active_ids() == ["collect_batteries"] and objectives.get_progress(&"collect_batteries") == 2, "objectives restored at 2/3 (%s)" % [active_ids()])
	check(not room2.get_node("LockedDoor").locked, "storage door still unlocked")
	var p2 = player()
	check(p2.global_position.distance_to(Vector3(8, 0, -9.5)) < 0.3, "player at storage checkpoint (%s)" % p2.global_position)
	check(events.count(&"entered_dark_room") == dark_count, "dark room scare not replayed")
	check(not room2.get_node("Scares/DarkRoomFlicker").is_flickering, "room light not flickering after load")
	check(not room2.get_node("Scares/Figure").visible, "figure hidden after load")
	check(absf(room2.get_node("Door").hinge.rotation.y) < 0.01, "tape door-slam not replayed")
	var panel: Array = room2.get_node("HUD/Objectives").get_children().map(func(l): return l.text)
	check(panel == ["Collect batteries  2/3"], "panel shows restored objective only (%s)" % [panel])
	check(room2.get_node("Camcorder").osd.elapsed > 0.1, "camcorder clock continues (%.1f s)" % room2.get_node("Camcorder").osd.elapsed)

	# --- Finish the tape ---
	room2.get_node("Battery3").interactable.interact(p2)
	await physics(2)
	p2.global_position = Vector3(0, 0, 11)
	await physics(6)
	check(events.has_fired(&"test_exit"), "exit zone fired")
	await game.transition_finished
	check(game.is_completed(&"tape_00_test"), "chapter marked completed")
	check(game.current_chapter == null and not game.has_checkpoint(), "back at hub: no chapter, checkpoint cleared")
	check(events.count(&"test_exit") == 0, "events reset after completion")
	check(current_scene != room2 and not paused, "hub loaded")

	# --- Save survives a restart ---
	game.load_save()
	check(game.is_completed(&"tape_00_test"), "completion persisted to disk")

	game.delete_save()
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
