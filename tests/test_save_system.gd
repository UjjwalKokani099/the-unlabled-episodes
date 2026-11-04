extends SceneTree
# Save system (studio spec 8 / build step 5): checkpoints store chapter, checkpoint id,
# objectives, inventory, story flags, play time and the doors/lights that matter; the save
# icon shows for ~2 s; nothing saves mid-scare, mid-dialogue, mid-tape-cut or mid-chase (the
# checkpoint waits and is written once it's safe); story-beat autosaves; doors, switch and
# inventory come back on load; the loading card warms the level's shaders. Separate save.
# Run: <console exe> --path . --quit-after 9000 --script res://tests/test_save_system.gd

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
	var game = root.get_node("GameManager")
	var events = root.get_node("EventBus")
	var saves = root.get_node("SaveManager")
	var loader = root.get_node("SceneLoader")
	game.save_path = "user://test_save.json"
	game.delete_save()
	game.mark_intro_seen()

	check(game.start_chapter(&"tape_00_test"), "test tape starts")
	await game.transition_finished
	var room: Node = current_scene
	check(DisplayServer.get_name() == "headless" or loader.last_warmup_count > 5,
		"loading card warmed the level's shaders (%d materials)" % loader.last_warmup_count)
	var p = room.get_node("Player")

	# --- change the world, then save
	var door = room.get_node("Door")
	var sw = room.get_node("LightSwitch")
	door.open_away_from(p.global_position)
	sw.set_on(not sw.is_on)
	var switch_state: bool = sw.is_on
	room.get_node("Battery1").get_node("Interactable").interact(p)
	await create_timer(0.9).timeout
	game.save_checkpoint(&"start")
	var cp: Dictionary = saves.data.checkpoint
	check(cp.get("checkpoint") == "start" and cp.has("objectives") and cp.has("world") and cp.has("inventory")
		and cp.has("flags") and cp.has("play_time"), "checkpoint has objectives, world, inventory, flags, play time")
	check(game.has_item(&"battery") and cp.inventory.size() == 1, "inventory saved (%s)" % [cp.inventory])
	var door_key := String(room.get_path_to(door))
	check(cp.world.has(door_key) and cp.world[door_key].open, "door state in the save")
	check(cp.world.has(String(room.get_path_to(sw))), "light switch state in the save")
	var hud = room.get_node("HUD")
	check(hud.save_indicator.is_showing(), "save icon shows")
	await create_timer(2.6).timeout
	check(not hud.save_indicator.visible, "save icon gone after ~2 s")
	var text := FileAccess.get_file_as_string(saves.save_path)
	check(text.contains("\"save_version\"") and FileAccess.file_exists(saves.save_path + ".bak"),
		"versioned save file + one backup")

	# --- never mid-scare: a scare reaction holds the checkpoint until it has played out
	events.fire(&"entered_dark_room")
	await frames(2)
	check(not game.can_save(), "scare running: saving held (%s)" % [game.save_blockers()])
	game.save_checkpoint(&"dark_room")
	check(saves.data.checkpoint.checkpoint == "start" and game.deferred_checkpoint() == &"dark_room",
		"checkpoint during the scare waits")
	var t := 0.0
	while saves.data.checkpoint.checkpoint != "dark_room" and t < 8.0:
		await create_timer(0.25).timeout
		t += 0.25
	check(saves.data.checkpoint.checkpoint == "dark_room" and t > 1.5,
		"...and is written once the scare is over (%.1f s later)" % t)

	# --- dialogue, tape cut, chase
	var view = hud.get_node("DialogueView")
	view.instant = true
	view.play("res://data/dialogue/tape01/secretary.json")
	await frames(1)
	check(not game.can_save(), "dialogue open: saving held")
	view.stop()
	check(game.can_save(), "dialogue closed: saving free")
	game.block_saving(&"cutscene")
	check(not game.can_save(), "cutscene hold")
	game.unblock_saving(&"cutscene")
	game.block_saving(&"short", 0.3)
	await create_timer(0.5).timeout
	check(game.can_save(), "timed holds release themselves")

	# --- story-beat autosave
	var auto = load("res://systems/events/autosave_reaction.gd").new()
	auto.on_event = &"story_beat_test"
	auto.checkpoint_id = &"start"
	room.add_child(auto)
	saves.data.checkpoint.checkpoint = "x"
	events.fire(&"story_beat_test")
	await frames(3)
	check(saves.data.checkpoint.checkpoint == "start", "story beat autosaves")
	door.open_away_from(p.global_position)
	await create_timer(0.8).timeout
	game.save_checkpoint(&"start", true)

	# --- load: world, inventory come back
	door.close()
	sw.set_on(not switch_state)
	game.inventory.clear()
	check(game.load_checkpoint(), "load checkpoint")
	await game.transition_finished
	room = current_scene
	check(room.get_node("Door").is_open and absf(room.get_node("Door").hinge.rotation.y) > 1.0, "door open again after load")
	check(room.get_node("LightSwitch").is_on == switch_state, "light switch as saved")
	check(game.has_item(&"battery") and not room.has_node("Battery1"), "inventory back, picked battery stays gone")
	check(game.can_save() and game.deferred_checkpoint() == &"", "no stale holds after loading")

	game.delete_save()
	game.save_path = saves.DEFAULT_PATH
	current_scene.queue_free()
	await frames(3)
	print("RESULT fails=%d" % fails)
	quit()
