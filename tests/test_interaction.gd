extends SceneTree
# Interaction system: focus + prompts, instant use (door, switch), locked door, hold-to-pick-up.
# Run: <console exe> --path . --quit-after 4000 --script res://tests/test_interaction.gd

var fails := 0
var p  # Player (untyped: autoloads aren't registered yet when this file compiles)
var room: Node

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func stand_at(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p._pitch = pitch_deg
	p.head.rotation.x = deg_to_rad(pitch_deg)
	await frames(6)

func send_interact(pressed: bool) -> void:
	if pressed:
		Input.action_press("interact")
	else:
		Input.action_release("interact")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await frames(2)

func tap_interact() -> void:
	await send_interact(true)
	await send_interact(false)

func focused_prompt() -> String:
	var f = p.interactor.focused
	return f.prompt if f else "<nothing>"

func _initialize() -> void:
	room = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	p = room.get_node("Player")
	await frames(30)

	# Nothing in reach at spawn
	check(p.interactor.focused == null, "nothing focused at spawn")

	# --- Door ---
	var door = room.get_node("Door")
	await stand_at(Vector3(6, 0, -1.0), 0, 0)  # 3 m away: out of reach
	check(p.interactor.focused == null, "door out of reach at 3 m")
	await stand_at(Vector3(6, 0, -2.5), 0, 0)
	check(focused_prompt() == "Open", "door focused, prompt 'Open' (got %s)" % focused_prompt())
	check(room.get_node("HUD/Prompt").visible and room.get_node("HUD/Prompt").text == "[E] Open", "HUD shows '%s'" % room.get_node("HUD/Prompt").text)
	await tap_interact()
	await frames(60)
	check(door.is_open and absf(rad_to_deg(door.hinge.rotation.y) - 100.0) < 1.0, "door swung open away from player (%.1f deg)" % rad_to_deg(door.hinge.rotation.y))
	# Door now hangs on the far side; look at it again to close
	await stand_at(Vector3(5.9, 0, -3.0), 25, 0)
	if focused_prompt() == "Close":
		await tap_interact()
		await frames(60)
		check(not door.is_open and absf(door.hinge.rotation.y) < 0.02, "door closes")
	else:
		check(false, "open door focusable for closing (got %s)" % focused_prompt())
	# Open from the dark side: swings the other way
	await stand_at(Vector3(6, 0, -5.5), 180, 0)
	check(focused_prompt() == "Open", "door focusable from the other side (got %s)" % focused_prompt())
	await tap_interact()
	await frames(60)
	check(rad_to_deg(door.hinge.rotation.y) < -99.0, "opens away from player on other side (%.1f deg)" % rad_to_deg(door.hinge.rotation.y))

	# --- Locked door ---
	var locked = room.get_node("LockedDoor")
	await stand_at(Vector3(8, 0, -11.0), 0, 0)
	check(focused_prompt() == "Open", "locked door focused (got %s)" % focused_prompt())
	await tap_interact()
	await frames(30)
	check(not locked.is_open, "locked door stays shut")
	check(room.get_node("HUD/Message").text == "Locked. Maybe the tape has a clue.", "locked message shown")
	await frames(20)
	check(absf(locked.hinge.rotation.y) < 0.001, "rattle returns to closed")

	# --- Light switch ---
	var light: Light3D = room.get_node("RoomLight")
	await stand_at(Vector3(3, 0, 2.5), 0, -10)
	check(focused_prompt() == "Turn off light", "switch focused (got %s)" % focused_prompt())
	await tap_interact()
	check(not light.visible and focused_prompt() == "Turn on light", "light turned off, prompt flips")
	await tap_interact()
	check(light.visible, "light turned back on")

	# --- Wall blocks the ray: crawl-hole side, tape behind the divider wall ---
	await stand_at(Vector3(5, 0, -3.0), 0, 0)
	check(p.interactor.focused == null, "can't use things through walls")

	# --- Hold to pick up ---
	var tape = room.get_node("VHSTape")
	await stand_at(Vector3(5, 0, -7.6), 0, -5)
	check(focused_prompt() == "Pick up tape", "tape focused (got %s)" % focused_prompt())
	check(room.get_node("HUD/Prompt").text == "Hold [E] Pick up tape", "hold prompt text")
	await send_interact(true)
	await frames(30)
	check(is_instance_valid(tape) and p.interactor.hold_ratio > 0.3, "holding fills ring (%.2f)" % p.interactor.hold_ratio)
	await send_interact(false)
	check(is_instance_valid(tape) and p.interactor.hold_ratio == 0.0, "releasing early cancels")
	await send_interact(true)
	await frames(75)
	await send_interact(false)
	check(not is_instance_valid(tape), "tape picked up after 1 s hold")
	check(room.get_node("HUD/Message").text == "Picked up: VHS tape", "pickup message shown")
	check(p.interactor.focused == null, "focus cleared after pickup")

	# --- Disabled when mouse is free ---
	await stand_at(Vector3(3, 0, 2.5), 0, -10)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(3)
	check(p.interactor.focused == null, "no focus while mouse is released")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	print("RESULT fails=", fails)
	quit(fails)
