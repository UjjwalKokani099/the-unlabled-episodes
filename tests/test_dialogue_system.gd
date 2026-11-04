extends SceneTree
# Dialogue, subtitles, objectives (studio spec 5/6, build step 6a): every dialogue file in
# data/dialogue passes the parser's validate(); lines with `duration` move on by themselves;
# timed choices drain and take their `timeout` choice; inner monologue shows in italics with
# no name; objectives sit top-left, fade in and play the update sound.
# Run: <console exe> --path . --quit-after 6000 --script res://tests/test_dialogue_system.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func dialogue_files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(dialogue_files(dir.path_join(sub)))
	return out


func _initialize() -> void:
	await process_frame
	var dlg = load("res://systems/dialogue/dialogue.gd")
	# --- parser: every file is valid
	var files := dialogue_files("res://data/dialogue")
	var bad := []
	for f in files:
		var d = dlg.load_file(f)
		if d == null:
			bad.append(f)
			continue
		var problems: PackedStringArray = d.validate()
		if not problems.is_empty():
			bad.append("%s: %s" % [f, problems])
	check(files.size() >= 3 and bad.is_empty(), "%d dialogue files valid %s" % [files.size(), bad])
	# a broken file is caught
	var broken = dlg.new()
	broken.path = "broken"
	broken.start = "a"
	broken.nodes = {"a": {"text": "hi", "next": "nowhere", "choices": [{"text": "x", "if": "weird:1"}]}}
	check(broken.validate().size() >= 2, "validate() catches missing links and unknown conditions")

	# --- runtime: duration + timed choice, on the test room's HUD
	var room: Node = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	await frames(10)
	var tmp := "user://test_dialogue.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"start": "a", "nodes": {
		"a": {"speaker": "CALLER", "text": "Are you there?", "duration": 0.4, "next": "b"},
		"b": {"speaker": "CALLER", "text": "Open the gate.", "timer": 0.8, "timeout": 1, "choices": [
			{"text": "Yes.", "next": "yes"}, {"text": "(Say nothing)", "next": "no", "set": {"test_silent": true}}]},
		"yes": {"speaker": "CALLER", "text": "Good."},
		"no": {"speaker": "CALLER", "text": "...", "duration": 0.3}}}))
	f.close()
	var view = room.get_node("HUD/DialogueView")
	view.instant = true
	view.play(tmp)
	await frames(2)
	check(view.current_id == "a", "first line shows")
	await create_timer(0.7).timeout
	check(view.current_id == "b" and view.choice_texts().size() == 2, "a line with `duration` moves on by itself")
	check(view.time_left() > 0.0, "timed choice: the clock runs (%.2f s)" % view.time_left())
	await create_timer(1.0).timeout
	check(dlg.flag("test_silent") == true, "time ran out: the `timeout` choice was taken")
	await create_timer(0.6).timeout
	check(not view.is_open, "conversation ends after the last timed line")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# --- inner monologue
	var subs = room.get_node("HUD/Subtitles")
	subs.think("Probably just the pipes.", 2.0)
	await frames(2)
	check(subs.current_text() == "Probably just the pipes." and subs._label.text.contains("[i]"),
		"inner monologue: italics, no speaker name ('%s')" % subs.current_text())

	# --- objectives: top-left, fade, sound
	var panel = room.get_node("HUD/Objectives")
	var vp: Vector2 = panel.get_viewport_rect().size
	check(panel.get_global_rect().position.x < vp.x * 0.25 and panel.get_global_rect().position.y < vp.y * 0.25,
		"objectives sit top-left (%s)" % panel.get_global_rect().position)
	var ui: AudioStreamPlayer = root.get_node("AudioManager")._ui
	ui.stop()
	root.get_node("EventBus").fire(&"vhs_tape")
	await frames(2)
	check(ui.playing and ui.stream.resource_path.ends_with("objective_update.wav"), "objective update plays its sound")
	await create_timer(0.6).timeout
	check(panel.modulate.a > 0.9 and panel.line_texts().size() > 0, "objective fades in (%s)" % [panel.line_texts()])

	room.queue_free()
	await frames(3)
	print("RESULT fails=%d" % fails)
	quit()
