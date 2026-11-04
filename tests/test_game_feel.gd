extends SceneTree
# Game feel numbers from the studio spec: walk 2.2 / crouch 1.2 / run 3.8 m/s, eased start
# (~0.2 s) and stop (~0.15 s), running off where the chapter forbids it, footstep clips never
# repeating back to back, 7 surfaces x 5 variants, head bob dipping on each footfall and
# scaled by the head-bob setting. Uses the test room.
# Run: <console exe> --path . --quit-after 6000 --script res://tests/test_game_feel.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func speed_of(p) -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _initialize() -> void:
	await process_frame
	var settings = root.get_node("SettingsManager")
	var game = root.get_node("GameManager")
	var saved := {"bob": settings.head_bob_intensity, "reduce": settings.reduce_camera_motion}
	var room: Node = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	var p = room.get_node("Player")
	await physics(20)
	p.global_position = Vector3(0, 0.05, 2)
	p.rotation.y = 0.0
	await physics(10)

	check(is_equal_approx(p.walk_speed, 2.2) and is_equal_approx(p.crouch_speed, 1.2) and is_equal_approx(p.sprint_speed, 3.8),
		"spec speeds: walk 2.2, crouch 1.2, run 3.8")

	# --- eased start and stop (60 physics frames per second)
	Input.action_press("move_forward")
	await physics(3)
	var early: float = speed_of(p)
	await physics(9)  # 0.2 s in
	var at_accel: float = speed_of(p)
	check(early > 0.05 and early < p.walk_speed * 0.7, "no instant start (%.2f m/s after 0.05 s)" % early)
	check(at_accel > p.walk_speed * 0.9, "near full speed after 0.2 s (%.2f)" % at_accel)
	Input.action_release("move_forward")
	await physics(2)
	var braking: float = speed_of(p)
	await physics(8)  # ~0.17 s after letting go
	check(braking > 0.3, "no instant stop (%.2f m/s just after release)" % braking)
	check(speed_of(p) < p.walk_speed * 0.12, "stopped within ~0.15 s (%.2f)" % speed_of(p))

	# --- running, and a chapter that forbids it
	p.global_position = Vector3(0, 0.05, 2)
	await physics(5)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await physics(30)
	check(p.is_sprinting and absf(speed_of(p) - 3.8) < 0.2, "running at 3.8 m/s (%.2f)" % speed_of(p))
	var calm: Resource = load("res://chapters/chapter_01/chapter.tres").duplicate()
	calm.allow_running = false
	game.current_chapter = calm
	await physics(30)
	check(not p.is_sprinting and absf(speed_of(p) - 2.2) < 0.15, "no running where the chapter forbids it (%.2f)" % speed_of(p))
	game.current_chapter = null
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await physics(20)

	# --- footstep variety
	var steps = p.get_node("Footsteps")
	for surface in [&"wood", &"carpet", &"tile", &"concrete", &"gravel", &"grass", &"metal"]:
		var set: Resource = steps.SOUND_SETS[surface]
		var last: AudioStream = null
		var repeats := 0
		var seen := {}
		for i in 60:
			var clip: AudioStream = set.pick()
			if clip == last:
				repeats += 1
			last = clip
			seen[clip] = true
		check(set.streams.size() >= 4 and repeats == 0 and seen.size() == set.streams.size(),
			"%s: %d variants, never the same twice in a row" % [surface, set.streams.size()])
		var pitch: float = set.random_pitch()
		check(pitch >= 0.95 and pitch <= 1.05, "%s: pitch within +-5%%" % surface)

	# --- head bob locked to footfalls
	settings.head_bob_intensity = 1.0
	settings.reduce_camera_motion = false
	p.global_position = Vector3(0, 0.05, 2)
	await physics(5)
	var cam: Camera3D = p.camera
	var at_step := []
	var mid_step := []
	var last_count: int = steps.steps_taken
	Input.action_press("move_forward")
	for i in 150:
		await physics_frame
		if steps.steps_taken != last_count:
			last_count = steps.steps_taken
			at_step.append(cam.position.y)
		elif absf(steps.phase() - 0.5) < 0.08:
			mid_step.append(cam.position.y)
	Input.action_release("move_forward")
	var avg := func(a: Array) -> float:
		var t := 0.0
		for v in a:
			t += v
		return t / maxf(a.size(), 1)
	check(at_step.size() >= 3 and avg.call(at_step) < avg.call(mid_step),
		"camera is lower on footfalls than between them (%.3f vs %.3f)" % [avg.call(at_step), avg.call(mid_step)])
	await physics(30)
	settings.head_bob_intensity = 0.0
	Input.action_press("move_forward")
	var max_bob := 0.0
	for i in 60:
		await physics_frame
		max_bob = maxf(max_bob, absf(cam.position.y))
	Input.action_release("move_forward")
	check(max_bob < 0.004, "head bob 0%% = steady camera (%.4f m)" % max_bob)

	settings.head_bob_intensity = saved.bob
	settings.reduce_camera_motion = saved.reduce
	room.queue_free()
	await physics(3)
	print("RESULT fails=%d" % fails)
	quit()
