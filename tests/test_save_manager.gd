extends SceneTree
# SaveManager unit test: versioned schema, atomic write (temp + rename, previous file kept
# as .bak), recovery from a corrupted slot via the backup, migration of the old v1 save
# (user://save.json format), delete. Uses its own path; never touches the player's save.
# Run: <console exe> --path . --quit-after 2000 --script res://tests/test_save_manager.gd

const PATH := "user://saves_test/slot.json"

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	await process_frame
	var sm = root.get_node("SaveManager")
	var saved_path: String = sm.save_path
	sm.save_path = PATH
	sm.delete_save()

	check(not sm.exists() and int(sm.data.save_version) == sm.SAVE_VERSION, "fresh data at the current version")
	sm.data.completed = ["tape_01_watchman"]
	check(sm.write() and sm.exists(), "write creates the slot (and its folder)")
	check(not FileAccess.file_exists(PATH + ".tmp"), "no temp file left behind")
	sm.data.intro_seen = true
	sm.write()
	check(FileAccess.file_exists(PATH + ".bak"), "second write keeps the previous file as .bak")

	# corrupt the slot: load falls back to the backup
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	sm.load_save()
	check(sm.recovered_from_backup and "tape_01_watchman" in sm.data.completed, "corrupted slot: restored from the backup")

	# migration from v1 (the old save.json layout)
	var v1 := {"version": 1, "completed": ["tape_01_watchman"], "checkpoint": {}, "intro_seen": true,
		"spotted": ["t1_flat_4b"]}
	var migrated: Dictionary = sm.migrate(v1)
	check(int(migrated.save_version) == 2 and not migrated.has("version"), "v1 -> v2: version key renamed")
	check(migrated.has("play_time") and migrated.has("chapter_times"), "v1 -> v2: play time fields added")
	check(migrated.spotted == ["t1_flat_4b"] and migrated.intro_seen, "v1 -> v2: progress kept")

	sm.delete_save()
	check(not sm.exists() and not FileAccess.file_exists(PATH + ".bak"), "delete removes slot and backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves_test"))
	sm.save_path = saved_path
	sm.load_save()
	print("RESULT fails=%d" % fails)
	quit()
