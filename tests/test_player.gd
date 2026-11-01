extends SceneTree
# Drives the player in the test room with simulated input and checks the results.

var fails := 0
var p

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func teleport(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await frames(5)

func _initialize() -> void:
	var room: Node = load("res://scenes/test/test_room.tscn").instantiate()
	root.add_child(room)
	p = room.get_node("Player")
	await frames(30)
	print("mouse captured: ", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	check(p.is_on_floor() and absf(p.global_position.y) < 0.05, "player lands on floor (y=%.3f)" % p.global_position.y)


	# Walk forward
	var z0: float = p.global_position.z
	Input.action_press("move_forward")
	await frames(60)
	var walk_speed: float = Vector2(p.velocity.x, p.velocity.z).length()
	check(p.global_position.z < z0 - 1.5, "walks forward (dz=%.2f)" % (p.global_position.z - z0))
	check(absf(walk_speed - p.walk_speed) < 0.1, "walk speed %.2f" % walk_speed)
	Input.action_press("sprint")
	await frames(40)
	var sprint_speed: float = Vector2(p.velocity.x, p.velocity.z).length()
	check(p.is_sprinting and absf(sprint_speed - p.sprint_speed) < 0.15, "sprint speed %.2f" % sprint_speed)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await frames(40)
	check(Vector2(p.velocity.x, p.velocity.z).length() < 0.05, "stops when keys released")

	# Crouch
	Input.action_press("crouch")
	await frames(40)
	check(p.is_crouching and absf(p._height - p.crouch_height) < 0.02, "crouch height %.2f" % p._height)
	check(absf(p.head.position.y - (p.crouch_height - p.eye_below_top)) < 0.02, "head lowered")

	# Crouched into the crawl hole, release crouch: must stay crouched
	await teleport(Vector3(-6, 0, -4))
	Input.action_release("crouch")
	await frames(40)
	check(p.is_crouching and p._height < 1.2, "stays crouched under low ceiling (h=%.2f)" % p._height)
	# Crawl through to the dark side
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	await frames(40)
	check(p.global_position.z < -4.5, "crawled through hole (z=%.2f)" % p.global_position.z)
	check(not p.is_crouching and absf(p._height - p.stand_height) < 0.02, "stands up after leaving hole (h=%.2f)" % p._height)

	# Standing player cannot fit through the crawl hole
	await teleport(Vector3(-6, 0, -2.5))
	Input.action_press("move_forward")
	await frames(120)
	Input.action_release("move_forward")
	check(p.global_position.z > -3.8, "standing player blocked by crawl hole (z=%.2f)" % p.global_position.z)

	# Standing player walks through the (opened) doorway
	room.get_node("Door").open_away_from(Vector3(6, 0, -2.5))
	await frames(60)
	await teleport(Vector3(6, 0, -2.5))
	Input.action_press("move_forward")
	await frames(120)
	Input.action_release("move_forward")
	check(p.global_position.z < -5.0, "walks through doorway (z=%.2f)" % p.global_position.z)

	# Walk up the ramp (ramp rises toward +x)
	await teleport(Vector3(1.0, 0, 6.0))
	p.rotation.y = deg_to_rad(-90)  # face +x
	Input.action_press("move_forward")
	await frames(150)
	Input.action_release("move_forward")
	await frames(10)
	check(p.global_position.y > 1.1 and p.is_on_floor(), "climbs ramp (pos=%s)" % p.global_position)
	p.rotation.y = 0.0

	# Flashlight toggle via the input action
	var was_on: bool = p.flashlight.visible
	var ev := InputEventAction.new()
	ev.action = &"flashlight"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	check(p.flashlight.visible != was_on, "flashlight toggles")

	print("RESULT fails=", fails)
	quit(fails)
