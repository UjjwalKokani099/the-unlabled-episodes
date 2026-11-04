extends SceneTree
# Scripted sequences + cutscenes (studio spec 9, build step 7): every file in data/sequences
# validates against its level; a sequence runs its steps on its trigger, once, holding saving;
# a cutscene takes input, letterboxes, can be skipped (effects still applied) and gives
# control back; `look` turns the player's view; the END OF TAPE screen fades, shows the card,
# waits for a key.
# Run: <console exe> --path . --quit-after 60000 --script res://tests/test_sequences.gd

var fails := 0
var game: Node
var events: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func until(cond: Callable, seconds: float = 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func write_json(path: String, data: Dictionary) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	return path


func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	events = root.get_node("EventBus")
	game.save_path = "user://test_sequences_save.json"
	game.delete_save()

	# --- Tape 1's sequence files validate against the real level
	var tape: Node = load("res://chapters/chapter_01/shanti_vihar.tscn").instantiate()
	tape.get_node("Story").set_process(false)
	root.add_child(tape)
	await frames(3)
	var seqs = tape.get_node_or_null("Story/Sequences")
	check(seqs != null, "the Tape 1 director owns a SequencePlayer")
	if seqs:
		for id in ["t1_intercom", "t1_deshmukh_312", "t1_ending"]:
			var problems: PackedStringArray = seqs.validate(id)
			check(problems.is_empty(), "%s validates %s" % [id, problems])
	tape.queue_free()
	await frames(3)

	# --- a small level with a player
	change_scene_to_file("res://tests/scenes/test_room.tscn")
	await frames(4)
	var lv: Node = current_scene
	var p: Node = get_first_node_in_group("player")
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_energy = 1.0
	lv.add_child(lamp)
	var box := Node3D.new()
	box.name = "Box"
	box.position = Vector3(3, 1.0, -2)
	lv.add_child(box)
	var shot := Node3D.new()
	shot.name = "Shot"
	shot.position = Vector3(0, 2.5, 3)
	lv.add_child(shot)

	var player = load("res://systems/sequence/sequence_player.gd").new()
	player.name = "Sequences"
	player.root = NodePath("..")
	player.time_scale = 0.2
	lv.add_child(player)
	var a: String = player.load_sequence(write_json("user://seq_a.json", {
		"id": "seq_test_a", "trigger": {"event": "seq_go"}, "steps": [
			{"do": "hide", "node": "Box"},
			{"do": "wait", "seconds": 1.0},
			{"do": "light", "node": "Lamp", "energy": 0.25},
			{"do": "parallel", "steps": [
				{"do": "fire", "event": "seq_par_1"},
				{"do": "wait", "seconds": 0.5}]},
			{"do": "if", "cond": "event:seq_par_1", "then": [{"do": "fire", "event": "seq_branch_yes"}],
				"else": [{"do": "fire", "event": "seq_branch_no"}]},
			{"do": "fire", "event": "seq_a_done"}]}))
	check(a == "seq_test_a", "a sequence file loads")
	check(player.validate(a).is_empty(), "it validates")
	var bad: String = player.load_sequence(write_json("user://seq_bad.json", {
		"id": "seq_bad", "steps": [{"do": "teleport"}, {"do": "show", "node": "Nope"}]}))
	check(player.validate(bad).size() == 2, "validate() lists an unknown step and a missing node")

	events.fire(&"seq_go")
	await frames(2)
	check(player.is_running(a) and not box.visible, "its event starts it; steps run in order")
	check(not game.can_save(), "a running sequence holds saving")
	check(await until(func() -> bool: return events.has_fired(&"seq_a_done"), 4.0), "it finishes")
	check(is_equal_approx(lamp.light_energy, 0.25), "light step set the energy")
	check(events.has_fired(&"seq_branch_yes") and not events.has_fired(&"seq_branch_no"), "if/parallel steps")
	check(game.can_save(), "saving is free again afterwards")
	events.fire(&"seq_go")
	await frames(2)
	check(not player.is_running(a), "once: the same event doesn't replay it")

	# --- look: the player's own view turns to a node, then control comes back
	var l: String = player.load_sequence(write_json("user://seq_look.json", {
		"id": "seq_look", "trigger": {"event": "seq_look_go"}, "steps": [
			{"do": "look", "at": "Box", "seconds": 1.0, "hold": 0.5}]}))
	events.fire(&"seq_look_go")
	await frames(2)
	check(not p.input_enabled, "look: input is held while the view turns")
	await until(func() -> bool: return not player.is_running(l), 4.0)
	var to: Vector3 = p.camera.global_position.direction_to(box.global_position)
	var facing: Vector3 = -p.camera.global_basis.z
	check(facing.dot(to) > 0.97, "look: the view ends on the target (dot %.3f)" % facing.dot(to))
	check(p.input_enabled, "look: control comes back")

	# --- a cutscene: input off, letterbox, camera shot, skip -> effects still applied
	var c: String = player.load_sequence(write_json("user://seq_cut.json", {
		"id": "seq_cut", "trigger": {"event": "seq_cut_go"}, "cutscene": true, "steps": [
			{"do": "letterbox", "on": true},
			{"do": "camera", "shot": "Shot", "blend": 1.0, "seconds": 20.0},
			{"do": "wait", "seconds": 40.0},
			{"do": "show", "node": "Box"},
			{"do": "fire", "event": "seq_cut_done"}]}))
	events.fire(&"seq_cut_go")
	await wait(0.5)
	check(player.is_running(c) and not p.input_enabled, "cutscene: the player can't move")
	check(player._ui.is_letterboxed(), "cutscene: letterbox bars")
	check(root.get_camera_3d() != p.camera, "cutscene: a cinematic camera took over")
	player._ui.set_skip_progress(0.6)
	check(player._ui._ring.visible, "holding E shows the skip ring")
	player.skip()
	check(await until(func() -> bool: return not player.is_running(c), 3.0), "skipping ends it at once")
	check(events.has_fired(&"seq_cut_done") and box.visible, "skipped steps still applied their effects")
	await frames(2)
	check(p.input_enabled and root.get_camera_3d() == p.camera, "control and the player's camera are back")
	check(not player._ui.is_letterboxed(), "letterbox gone")

	# --- time trigger
	var t: String = player.load_sequence(write_json("user://seq_time.json", {
		"id": "seq_time", "trigger": {"time": 1.0}, "steps": [{"do": "fire", "event": "seq_timed"}]}))
	check(await until(func() -> bool: return events.has_fired(&"seq_timed"), 3.0), "time trigger fires")
	check(t == "seq_time", "time sequence loaded")

	# --- END OF TAPE screen
	var screen = load("res://ui/menus/chapter_complete.gd").new()
	screen.chapter = load("res://chapters/chapter_01/chapter.tres")
	screen.runtime = 3725.0
	screen.auto_continue = 60.0
	var closed := [false]
	screen.closed.connect(func() -> void: closed[0] = true)
	root.add_child(screen)
	await wait(0.8)
	check(not screen.is_showing_card() and screen._black.modulate.a > 0.2, "end of tape: the picture fades to black first")
	check(await until(func() -> bool: return screen.is_showing_card(), 6.0), "then the card comes up")
	var labels := []
	for n in screen.find_children("*", "Label", true, false):
		labels.append(n.text)
	check("END OF TAPE" in labels and "RUNTIME 1:02:05" in str(labels), "card: END OF TAPE + runtime %s" % [labels])
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	screen._input(key)
	check(not closed[0], "a key during the guard does nothing")
	await wait(1.4)
	screen._input(key)
	check(closed[0], "any key closes it")
	screen.queue_free()

	game.delete_save()
	for f in ["user://seq_a.json", "user://seq_bad.json", "user://seq_look.json", "user://seq_cut.json", "user://seq_time.json"]:
		DirAccess.remove_absolute(f)
	current_scene.queue_free()
	await frames(3)
	print("RESULT fails=", fails)
	quit(fails)
