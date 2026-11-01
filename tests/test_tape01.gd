extends SceneTree
# Tape 1 (Shanti Vihar): loads as a chapter, Raghu's round of duties completes the tape,
# the 4B spare key unlocks 4B, the CCTV renders. Separate save file.
# Run: <console exe> --path . --quit-after 30000 --script res://tests/test_tape01.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func physics(n: int) -> void:
	for i in n:
		await physics_frame

func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var obj: Node = root.get_node("Objectives")
	game.save_path = "user://test_save.json"
	game.delete_save()
	check(game.start_chapter(&"tape_01_watchman"), "tape 1 is built and starts")
	await game.transition_finished
	var lv: Node = current_scene
	var p = get_first_node_in_group("player")
	await physics(10)
	check(lv.get_node("Static").merged_into < 400, "6000+ boxes batched into %d meshes" % lv.get_node("Static").merged_into)
	check(lv.get_node("Camcorder").osd.get_node("Date").text == "MAR. 14 1998", "camcorder date 14 Mar 1998")
	check(game.saved_checkpoint_id() == &"start", "start checkpoint in the cabin")

	lv.get_node("GateRegister/Interactable").interact(p)
	lv.get_node("HUD/NoteView").close()
	lv.get_node("CCTV/Interactable").interact(p)
	await physics(2)
	check(obj.is_completed(&"sign_register") and obj.is_completed(&"check_cctv"), "register signed, CCTV checked")
	for letter in "ABCD":
		p.global_position = lv.get_node("Wing%s/Patrol" % letter).global_position - Vector3(0, 1, 0)
		await physics(6)
	check(obj.is_completed(&"patrol"), "patrolled the four wings")
	for letter in "ABCD":
		lv.get_node("Wing%s/TerraceLock/Interactable" % letter).interact(p)
	await physics(2)
	check(obj.is_completed(&"lock_terraces") and lv.get_node("WingA/TerraceDoor").locked, "terrace doors padlocked")
	check(lv.get_node("WingB/Door4B").locked, "4B locked")
	lv.get_node("KeyBoard/Interactable").interact(p)
	check(not lv.get_node("WingB/Door4B").locked, "spare key unlocks 4B")
	p.global_position = Vector3(5.75, 0.05, 23.6)
	await physics(6)
	check(root.get_node("Events").has_fired(&"back_at_cabin"), "back at the cabin ends the round")
	await game.transition_finished
	check(game.is_completed(&"tape_01_watchman") and current_scene.name == "Hub", "tape 1 complete, back in the hub")
	check(current_scene.stage == 1, "hub moves to stage 1 (the diary entry)")
	game.delete_save()
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
