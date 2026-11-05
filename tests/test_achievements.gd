extends SceneTree
# Achievements (studio spec 15): data/achievements.json; finishing a tape, spotting the
# Cameraman (first time, all of a tape's) and getting caught unlock them once; unlocks live
# in the save; no Steam singleton here = "local" backend, nothing breaks.
# Run: <console exe> --headless --path . --script res://tests/test_achievements.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	await process_frame
	var game = root.get_node("GameManager")
	var ach = root.get_node("Achievements")
	var events = root.get_node("EventBus")
	game.save_path = "user://test_achievements_save.json"
	game.delete_save()
	ach.reset()
	check(ach.definitions.size() >= 9, "achievements loaded (%d)" % ach.definitions.size())
	check(ach.backend() == "local", "no GodotSteam: local backend")
	var chapter_ids := []
	for ch in game.chapter_list.chapters:
		chapter_ids.append("chapter:" + String(ch.id))
	var missing := []
	for def in ach.definitions:
		var rule := String(def.unlock)
		if rule.begins_with("chapter:") and not rule in chapter_ids:
			missing.append(rule)
	check(missing.is_empty(), "every chapter rule names a real tape %s" % [missing])
	var got := []
	ach.unlocked.connect(func(id, _n): got.append(id))
	events.chapter_completed.emit(game.get_chapter(&"tape_01_watchman"))
	check(ach.is_unlocked(&"TAPE_01") and got == [&"TAPE_01"], "finishing Tape 1 unlocks TAPE_01")
	events.chapter_completed.emit(game.get_chapter(&"tape_01_watchman"))
	check(got.size() == 1, "only once")
	game.mark_spotted(&"t1_flat_4b")
	check(ach.is_unlocked(&"FIRST_SIGHTING") and not ach.is_unlocked(&"T1_ALL_SIGHTINGS"), "first sighting")
	game.mark_spotted(&"t1_cctv_stairs")
	game.mark_spotted(&"t1_d_balcony")
	check(ach.is_unlocked(&"T1_ALL_SIGHTINGS") and not ach.is_unlocked(&"ALL_SIGHTINGS"), "all three on Tape 1")
	events.player_caught.emit()
	check(ach.is_unlocked(&"TRACKING_LOST"), "caught: TRACKING_LOST")
	check(not ach.unlock(&"NOT_A_THING"), "unknown ids are ignored")
	var saved: Array = root.get_node("SaveManager").data.get("achievements", [])
	check("TAPE_01" in saved and "TRACKING_LOST" in saved, "unlocks are in the save")
	# a Steam-like backend (what GodotSteam's singleton looks like to this layer)
	var mock = load("res://tests/support_steam_mock.gd").new()
	ach.use_backend(mock)
	await process_frame
	check(ach.backend() == "steam" and mock.inited, "a Steam backend is initialised")
	check("TAPE_01" in mock.set_ids and mock.stored > 0, "earlier unlocks are pushed to it")
	events.chapter_completed.emit(game.get_chapter(&"tape_01_watchman"))
	game.mark_spotted(&"t2_road")
	check(mock.set_ids.count("FIRST_SIGHTING") == 1, "no duplicate pushes")
	ach.use_backend(load("res://tests/support_steam_mock.gd").new(false))
	check(ach.backend() == "local", "Steam not running: stays local")
	ach.reset()
	game.delete_save()
	print("RESULT fails=", fails)
	quit(fails)
