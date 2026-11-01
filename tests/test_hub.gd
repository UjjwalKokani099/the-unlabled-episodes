extends SceneTree
# Hub: tape labels/locks, picking up and swapping tapes, VCR prompts, insert -> chapter,
# return to hub -> resume, complete -> watched dot. Uses a separate save file.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_hub.gd

var fails := 0
var game: Node

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func physics(n: int) -> void:
	for i in n:
		await physics_frame

func player():
	return root.get_tree().get_first_node_in_group("player")

func look_from(pos: Vector3, pitch_deg: float) -> void:
	var p = player()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	p._pitch = pitch_deg
	p.head.rotation.x = deg_to_rad(pitch_deg)
	await physics(6)

func focused_prompt() -> String:
	var f = player().interactor.focused
	return f.prompt if f else "<nothing>"

func tap_interact() -> void:
	Input.action_press("interact")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics(2)
	Input.action_release("interact")
	await physics(1)

func message() -> String:
	return current_scene.get_node("HUD/Message").text

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.delete_save()
	change_scene_to_file("res://scenes/hub/hub.tscn")
	await scene_changed
	await physics(10)
	var hub: Node = current_scene
	var t1 = hub.get_node("Shelf/Tape01")
	var t2 = hub.get_node("Shelf/Tape02")
	var test_tape = hub.get_node("Shelf/TapeTest")

	# --- Labels ---
	check(t1.label.text == "TAPE 01\nTHE WATCHMAN", "tape 01 labelled ('%s')" % t1.label.text)
	check(t2.label.text == "" and t2.interactable.prompt == "Unlabeled tape", "locked tape 02 is blank")
	check(not t1.watched_dot.visible, "no watched dot yet")
	check(hub.vcr.interactable.prompt == "VCR", "VCR idle prompt")

	# --- Pick up by looking + E ---
	await look_from(Vector3(-2.28, 0, -1.4), -37)
	check(focused_prompt() == "Take TAPE 01 - THE WATCHMAN", "looking at tape 01 (%s)" % focused_prompt())
	await tap_interact()
	check(hub.held == t1 and t1.get_parent().name == "Hand", "tape 01 in hand")
	check(t1.interactable.collision_layer == 0, "held tape doesn't block the look-ray")
	t2.interactable.interact(player())
	check(hub.held == t1 and message().begins_with("No label"), "locked tape refuses")

	# Unbuilt tape won't play
	hub.use_vcr()
	check(message().contains("isn't made yet") and not hub.busy, "tape 01 not built: message, nothing starts")

	# Swap for the test tape
	var home: Transform3D = t1._home_transform
	test_tape.interactable.interact(player())
	check(hub.held == test_tape and t1.get_parent().name == "Shelf" and t1.transform.is_equal_approx(home), "swap puts tape 01 back on the shelf")
	check(t1.interactable.enabled and t1.interactable.collision_layer != 0, "tape 01 usable again")

	# Look at the VCR while holding (ray not blocked by the tape in hand)
	await look_from(Vector3(1.465, 0, -1.3), -47)
	check(focused_prompt() == "Insert TEST TAPE - GREY ROOM", "VCR prompt while holding (%s)" % focused_prompt())

	# --- Insert -> chapter starts ---
	await tap_interact()
	check(hub.busy and hub.tv.mode == 1 and not player().input_enabled, "insert: TV blue, player frozen")
	await game.transition_finished
	check(current_scene.name == "TestRoom" and game.current_chapter.id == &"tape_00_test", "test tape playing")
	await physics(10)
	check(game.saved_checkpoint_id() == &"start", "start checkpoint saved")

	# --- Leave mid-tape -> Resume in the hub ---
	game.return_to_hub()
	await game.transition_finished
	hub = current_scene
	check(hub.name == "Hub" and game.current_chapter == null, "back in the hub")
	check(hub.vcr.interactable.prompt == "Resume TEST TAPE - GREY ROOM", "VCR offers resume (%s)" % hub.vcr.interactable.prompt)
	hub.use_vcr()
	await game.transition_finished
	check(current_scene.name == "TestRoom" and player().global_position.distance_to(Vector3(0, 0, 9)) < 0.3, "resumed at the checkpoint")

	# --- Finish -> watched ---
	game.complete_chapter()
	await game.transition_finished
	hub = current_scene
	await physics(3)
	check(hub.name == "Hub", "completion returns to the hub")
	check(hub.get_node("Shelf/TapeTest").watched_dot.visible, "test tape marked watched")
	check(hub.vcr.interactable.prompt == "VCR", "no resume after finishing")

	game.delete_save()
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
