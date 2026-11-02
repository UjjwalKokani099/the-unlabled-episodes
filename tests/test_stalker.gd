extends SceneTree
# The Cameraman as a threat (scripts/characters/stalker.gd) in Tape 1's dark courtyard:
# patrol, being held in his shot -> HUNT -> CAUGHT, hiding (crouched in a HidingSpot) keeps
# you out of frame, losing him -> SEARCH, FOLLOWING only moves while unwatched, and the
# footsteps one floor up in B wing's stairs. Separate save file.
# Run: <console exe> --path . --quit-after 60000 --script res://tests/test_stalker.gd

const PATROL := 4
const HUNT := 5
const SEARCH := 6
const CAUGHT := 7
const FOLLOWING := 3
const ABSENT := 0

var fails := 0
var game: Node
var events: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func until(cond: Callable, timeout: float = 10.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await wait(0.05)
		t += 0.05
	return cond.call()


func goto(p, pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await physics(6)


## Puts the stalker at `at`, facing `look`, standing still in PATROL (no patrol walk).
func place(brain, at: Vector3, look: Vector3) -> void:
	brain.stop()
	brain.exposure = 0.0
	var body = brain.body
	body.global_position = at
	await physics(2)
	body.face(look)
	brain.patrol_points = PackedVector3Array([at])
	brain.start_patrol()
	body.face(look)


func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	events = root.get_node("Events")
	game.save_path = "user://test_save_stalker.json"
	game.delete_save()
	check(game.start_chapter(&"tape_01_watchman"), "tape 1 starts")
	await game.transition_finished
	var lv: Node = current_scene
	lv.get_node("Story").time_scale = 0.02
	var p = get_first_node_in_group("player")
	await wait(2.0)  # NavBaker bakes on a thread
	var brain = lv.get_node("Stalker/Brain")
	var body = brain.body
	brain.reload_on_catch = false
	check(brain.state == ABSENT and not body.visible, "absent until the power cut")
	check(not body.talk_area.enabled, "nobody talks to him")

	# ---- patrol: he walks his loop
	await goto(p, Vector3(-20, 0.05, 20))  # far away, out of his way
	var patrol_points: PackedVector3Array = brain.patrol_points
	brain.start_patrol()
	await physics(2)
	var start: Vector3 = body.global_position
	check(brain.state == PATROL and body.visible, "patrol starts")
	await wait(3.0)
	check(body.global_position.distance_to(start) > 1.0, "he walks the patrol (%.1f m)" % body.global_position.distance_to(start))
	check(brain.exposure == 0.0, "far away: not in his shot")

	# ---- in his shot: hunt, then caught
	var caught := [false]
	brain.caught.connect(func() -> void: caught[0] = true)
	await place(brain, Vector3(14, 0, 4), Vector3(14, 0, 14))
	await goto(p, Vector3(14, 0.05, 11))
	check(await until(func() -> bool: return brain.state == HUNT, 3.0), "seen 7 m in front: he hunts")
	check(brain.exposure > 0.25, "exposure rising (%.2f)" % brain.exposure)
	check(await until(func() -> bool: return caught[0], 5.0), "held in frame: caught")
	check(brain.state == CAUGHT, "state CAUGHT")
	var camcorder = get_first_node_in_group("camcorder")
	camcorder.hide_static()

	# ---- behind him: nothing
	await goto(p, Vector3(-20, 0.05, 20))
	await place(brain, Vector3(14, 0, 4), Vector3(14, 0, 14))
	await goto(p, Vector3(14, 0.05, -1))
	await wait(1.0)
	check(brain.state == PATROL and brain.exposure == 0.0, "behind his back: not seen")

	# ---- hiding: crouched behind the blue car, in his view, stays hidden
	await goto(p, Vector3(-20, 0.05, 20))
	await place(brain, Vector3(16, 0, 4), Vector3(16, 0, 14))
	Input.action_press(&"crouch")
	await goto(p, Vector3(16, 0.05, 12.6))
	await wait(0.5)
	check(p.is_crouching, "player crouched")
	check(lv.get_node("HideBlueCar").contains_player(), "inside the blue car's hiding spot")
	await wait(2.0)
	check(brain.state == PATROL and brain.exposure == 0.0, "crouched in a hiding spot: out of frame")
	Input.action_release(&"crouch")
	await wait(0.6)
	check(not p.is_crouching, "stood up")
	check(await until(func() -> bool: return brain.state == HUNT, 3.0), "standing up in his view: he hunts")

	# ---- lose him: break line of sight, he searches, then patrols again
	brain.seconds_to_catch_far = 100.0
	brain.seconds_to_catch_near = 100.0
	await goto(p, Vector3(-20, 0.05, 20))
	var lost_at: float = Time.get_ticks_msec() / 1000.0
	check(await until(func() -> bool: return brain.state == SEARCH, 9.0), "lost the player: he searches")
	check(Time.get_ticks_msec() / 1000.0 - lost_at > 5.0, "...only after ~6 s unseen")
	check(brain.exposure < 0.5, "exposure decays out of view (%.2f)" % brain.exposure)
	brain.seconds_to_catch_far = 3.2
	brain.seconds_to_catch_near = 1.2

	# ---- following: only moves while not looked at
	brain.stop()
	body.global_position = Vector3(-20, 0, 26)  # inside the compound (z -28..28)
	await goto(p, Vector3(-20, 0.05, 20))
	brain.follow()
	# CameraShake owns the camera's rotation: turn the player (yaw) instead.
	p.rotation.y = PI  # face +Z, towards him
	var watched_at: Vector3 = body.global_position
	await wait(1.5)
	check(brain.state == FOLLOWING and body.global_position.distance_to(watched_at) < 0.2, "watched: he stands still")
	p.rotation.y = 0.0  # turn away (face -Z)
	await wait(2.5)
	check(body.global_position.distance_to(watched_at) > 0.5, "unwatched: he comes closer (%.1f m)" % body.global_position.distance_to(watched_at))
	brain.stop()
	check(not body.visible, "stop(): gone")
	brain.patrol_points = patrol_points

	# ---- footsteps one floor up in B wing's stairs
	var steps = lv.get_node("StepsAboveB")
	var feet = p.get_node("Footsteps")
	await goto(p, Vector3(-12.5, 0.05, -16.9))
	feet.steps_taken += 3
	await physics(4)
	check(steps.steps_answered == 0, "not before the intercom")
	events.fire(&"intercom_answered")
	await physics(2)
	for i in 4:
		feet.steps_taken += 1
		await physics(3)
	check(steps.steps_answered == 4, "each step is answered from above (%d)" % steps.steps_answered)
	await wait(0.3)
	await physics(10)
	check(steps.steps_answered == 4, "standing still: silence above")

	game.delete_save()
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
