extends SceneTree
# No memory leaks across chapter loads (studio spec 12): room -> Tape 1 -> room, three
# times. After the first round warms the caches, object / node / resource counts and static
# memory must not grow from one round to the next.
# Run: <console exe> --path . --quit-after 60000 --script res://tests/test_leaks.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func sample() -> Dictionary:
	return {"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"mem": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0}


func _initialize() -> void:
	await process_frame
	var game = root.get_node("GameManager")
	game.save_path = "user://test_leaks_save.json"
	game.delete_save()
	game.chapter_complete_wait = 0.3
	var rounds := []
	for i in 3:
		game.enter_hub()
		await game.transition_finished
		await create_timer(1.0, true, false, true).timeout
		var s := sample()
		rounds.append(s)
		print("round %d: objects %d  nodes %d  resources %d  static %.1f MB" % [i, s.objects, s.nodes, s.resources, s.mem])
		game.start_chapter(&"tape_01_watchman")
		await game.transition_finished
		current_scene.get_node("Story").time_scale = 0.05
		await create_timer(1.0, true, false, true).timeout
	var a: Dictionary = rounds[1]
	var b: Dictionary = rounds[2]
	check(b.objects - a.objects <= 20, "objects stay flat across chapter loads (%+d)" % (b.objects - a.objects))
	check(b.nodes - a.nodes <= 4, "nodes stay flat (%+d)" % (b.nodes - a.nodes))
	check(b.resources - a.resources <= 4, "resources stay flat (%+d)" % (b.resources - a.resources))
	check(b.mem - a.mem < 2.0, "static memory stays flat (%+.2f MB)" % (b.mem - a.mem))
	game.delete_save()
	await load("res://tests/support.gd").finish(self, fails)
