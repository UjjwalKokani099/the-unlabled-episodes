extends SceneTree
# Audio system (studio spec step 3): per-place ambience beds that crossfade (~1.5 s) as the
# player moves between AcousticZones, the tension layers (story + stalker sources, highest
# wins), silence held before a scare, story tension rebuilt after a checkpoint reload, and
# voice lines that stay silent until recorded. Tape 1. Separate save file.
# Run: <console exe> --path . --quit-after 9000 --script res://tests/test_audio_system.gd

var fails := 0
var audio
var p


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func stand(pos: Vector3, settle: float = 2.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await physics(6)
	await create_timer(settle).timeout


func set_name() -> String:
	var s = audio.current_ambience()
	return s.resource_path.get_file().get_basename() if s else "<none>"


func bed(name: String) -> float:
	return audio.ambience_level(load("res://assets/audio/ambience/%s.ogg" % name))


func _initialize() -> void:
	await process_frame
	var game = root.get_node("GameManager")
	var events = root.get_node("EventBus")
	audio = root.get_node("AudioManager")
	game.save_path = "user://test_save.json"
	game.delete_save()
	check(game.start_chapter(&"tape_01_watchman"), "tape 1 starts")
	await game.transition_finished
	var lv: Node = current_scene
	lv.get_node("Story").time_scale = 0.02
	p = get_first_node_in_group("player")

	# --- ambience per place
	await stand(Vector3(5.75, 0.05, 23.6))
	check(set_name() == "cabin", "in the cabin: cabin beds (%s)" % set_name())
	check(absf(bed("room_tone") - (-2.0)) < 0.5 and absf(bed("crickets") - (-13.0)) < 0.5,
		"cabin: room tone up, crickets muffled (%.1f / %.1f dB)" % [bed("room_tone"), bed("crickets")])
	p.global_position = Vector3(0, 0.05, 10)
	await physics(6)
	await create_timer(0.4).timeout
	var mid: float = bed("crickets")
	check(mid > -13.0 and mid < -2.5, "crossfade is gradual, not a cut (crickets %.1f dB after 0.4 s)" % mid)
	await create_timer(2.0).timeout
	check(set_name() == "courtyard_night" and absf(bed("crickets") - (-2.0)) < 0.5, "courtyard: crickets full (%s %.1f dB)" % [set_name(), bed("crickets")])
	check(bed("room_tone") <= -59.0, "room tone faded out and stopped outside (%.1f)" % bed("room_tone"))
	await stand(Vector3(-12.5, 0.05, -15.0))
	check(set_name() == "stairwell", "B wing stairs: stairwell beds (%s)" % set_name())
	await stand(Vector3(-7, 12.05, -16.5))
	check(set_name() == "empty_flat", "inside 4B: only the room tone of an empty flat (%s)" % set_name())
	await stand(Vector3(28, 0.05, -4))
	check(set_name() == "meter_room" and bed("electric") > -6.0, "meter room: transformer hum (%s)" % set_name())

	# --- tension layers
	audio.set_tension(0.9, &"test", 2.0)
	await create_timer(1.0).timeout
	var t0: Array = []
	for i in 3:
		var tp: AudioStreamPlayer = audio.get_node("Tension%d" % i)
		t0.append(tp.playing)
	check(audio.tension() > 0.85 and t0[0] and t0[1] and t0[2], "high tension: low drone, rumble and high cluster all play (%.2f)" % audio.tension())
	audio.set_tension(0.2, &"test", 2.0)
	audio.set_tension(0.6, &"other", 2.0)
	await create_timer(0.8).timeout
	check(absf(audio.tension() - 0.6) < 0.05, "two sources: the higher wins (%.2f)" % audio.tension())
	audio.set_tension(0.0, &"test", 5.0)
	audio.set_tension(0.0, &"other", 5.0)
	await create_timer(0.6).timeout
	check(audio.tension() < 0.01 and not audio.get_node("Tension0").playing, "calm: drones stop")

	# --- silence before a scare
	audio.hold_silence(0.5, 0.2, 0.3)
	await create_timer(0.4).timeout
	check(audio.is_silenced() and audio.get_node(NodePath(str(audio.get_path_to(audio))))  != null, "hold_silence: everything drops out")
	await create_timer(1.0).timeout
	check(not audio.is_silenced(), "...and comes back")

	# --- story tension follows the night, and survives a reload
	events.fire(&"back_at_cabin")
	events.fire(&"deshmukh_left")
	await process_frame
	check(is_equal_approx(audio._tension_sources.get(&"story", -1.0), 0.3), "3:12 walk-out raises story tension to 0.3")
	game.save_checkpoint(&"start")
	check(game.load_checkpoint(), "reload checkpoint")
	await game.transition_finished
	current_scene.get_node("Story").time_scale = 0.02
	await create_timer(0.3).timeout
	check(is_equal_approx(audio._tension_sources.get(&"story", -1.0), 0.3), "after reload: story tension rebuilt (0.3)")

	# --- voice lines are optional
	check(audio.play_voice("t1/opening_1") == 0.0, "no VO recorded yet: subtitles only, no error")

	game.delete_save()
	game.save_path = "user://save.json"
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=%d" % fails)
	quit()
