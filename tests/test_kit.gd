extends SceneTree
# Building kit: static batching works, stairs are climbable, flat doors are locked/unlocked.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_kit.gd

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
	var level: Node = load("res://tests/scenes/kit_preview.tscn").instantiate()
	root.add_child(level)
	await physics(5)
	var batcher = level.get_node("Static")
	check(batcher.merged_from > 1000, "kit boxes merged: %d" % batcher.merged_from)
	check(batcher.merged_into < 120, "into %d batched meshes" % batcher.merged_into)

	# Walk up the first flight: ground landing (x 0.8, z 9.4) heading -Z.
	var p = level.get_node("Player")
	p.global_position = Vector3(0.8, 0.05, 9.4)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await physics(10)
	Input.action_press("move_forward")
	await physics(150)
	Input.action_release("move_forward")
	await physics(10)
	check(p.global_position.y > 1.3, "climbed the first flight to the mid landing (y=%.2f)" % p.global_position.y)

	var door_4b = level.get_node("WingB/Door4B")
	var door_3b = level.get_node("WingB/Door3B")
	check(not door_4b.locked and door_3b.locked, "4B unlocked (preview), other flats locked")
	check(level.get_node("WingB/Plate4B").text == "4B", "flat number plate")
	level.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
