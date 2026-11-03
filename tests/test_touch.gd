extends SceneTree
# Touch play (iPad / web): simulated finger touches drive the on-screen TouchControls.

var fails := 0
var p
var settings
var tc


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func touch(finger: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func drag(finger: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = finger
	ev.position = pos
	ev.relative = rel
	ev.screen_relative = rel
	Input.parse_input_event(ev)
	await process_frame


func mouse_move(rel: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = rel
	m.screen_relative = rel
	Input.parse_input_event(m)
	await process_frame
	await process_frame


func button_pos(name: StringName) -> Vector2:
	return tc._button_center(tc.BUTTONS[name])


func _initialize() -> void:
	await process_frame
	settings = root.get_node("/root/SettingsManager")
	var room: Node = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	p = room.get_node("Player")
	tc = room.get_node("HUD/TouchControls")
	await frames(30)
	var size: Vector2 = root.get_visible_rect().size

	check(not tc.visible, "hidden until the screen is touched")
	# first touch (top-middle, nothing there) switches to touch mode
	await touch(5, Vector2(size.x * 0.5, size.y * 0.1), true)
	await touch(5, Vector2(size.x * 0.5, size.y * 0.1), false)
	check(settings.touch_mode, "first touch: touch mode on")
	check(settings.mouse_captured(), "touch mode: game still in playing mode")
	await frames(2)
	check(tc.visible, "controls visible while playing")

	# move stick: finger down on the left, drag up = walk forward
	var z0: float = p.global_position.z
	var start := Vector2(size.x * 0.15, size.y * 0.7)
	await touch(0, start, true)
	await drag(0, start + Vector2(0, -120), Vector2(0, -120))
	await frames(60)
	check(p.global_position.z < z0 - 1.5, "stick up: walks forward (dz=%.2f)" % (p.global_position.z - z0))
	# RUN toggle while walking
	await touch(1, button_pos(&"run"), true)
	await touch(1, button_pos(&"run"), false)
	await frames(30)
	check(p.is_sprinting, "RUN toggle: sprinting")
	await touch(0, start, false)
	await frames(40)
	check(Vector2(p.velocity.x, p.velocity.z).length() < 0.05, "stick released: stops")
	check(not Input.is_action_pressed(&"sprint"), "stick released: RUN switches off")

	# look: drag on the right side turns the player; emulated mouse motion doesn't
	var yaw0: float = p.rotation.y
	var look_at := Vector2(size.x * 0.55, size.y * 0.4)
	await touch(2, look_at, true)
	await drag(2, look_at + Vector2(100, 0), Vector2(100, 0))
	await touch(2, look_at + Vector2(100, 0), false)
	check(absf(p.rotation.y - yaw0) > deg_to_rad(5.0), "drag right side: turns (%.1f deg)" % rad_to_deg(p.rotation.y - yaw0))
	var yaw1: float = p.rotation.y
	var mm := InputEventMouseMotion.new()
	mm.device = InputEvent.DEVICE_ID_EMULATION
	mm.relative = Vector2(200, 0)
	mm.screen_relative = Vector2(200, 0)
	Input.parse_input_event(mm)
	await frames(2)
	check(absf(p.rotation.y - yaw1) < 0.001, "emulated mouse motion from touch is ignored")
	check(settings.touch_mode, "...and doesn't leave touch mode")

	# DUCK toggle
	await touch(3, button_pos(&"duck"), true)
	await touch(3, button_pos(&"duck"), false)
	await frames(40)
	check(p.is_crouching, "DUCK toggle: crouched")
	await touch(3, button_pos(&"duck"), true)
	await touch(3, button_pos(&"duck"), false)
	await frames(60)
	check(not p.is_crouching, "DUCK again: stands up")

	# LIGHT button = flashlight key
	var light0: bool = p.flashlight.visible
	await touch(4, button_pos(&"light"), true)
	await touch(4, button_pos(&"light"), false)
	check(p.flashlight.visible != light0, "LIGHT toggles the flashlight")

	# MENU opens the pause menu: controls hide, taps go to the menu
	await touch(4, button_pos(&"pause"), true)
	await touch(4, button_pos(&"pause"), false)
	await frames(2)
	check(paused, "MENU pauses the game")
	check(not settings.mouse_captured(), "pause menu: out of playing mode")
	await process_frame
	check(not tc.visible, "controls hidden in the pause menu")
	room.get_node("HUD/PauseMenu").close()
	await frames(3)
	check(not paused and tc.visible, "resume: controls back")

	# browsers also report finger drags as (non-emulated) mouse motion: must stay in touch mode
	var z1: float = p.global_position.z
	var start2 := Vector2(size.x * 0.15, size.y * 0.7)
	await touch(0, start2, true)
	for i in 6:
		await drag(0, start2 + Vector2(0, -20 * (i + 1)), Vector2(0, -20))
		await mouse_move(Vector2(0, -40))
	await frames(40)
	check(settings.touch_mode and tc.visible, "mouse motion during a finger drag: still touch mode")
	check(p.global_position.z < z1 - 0.5, "...and the stick still walks (dz=%.2f)" % (p.global_position.z - z1))
	await touch(0, start2, false)
	await mouse_move(Vector2(200, 0))
	await frames(3)
	check(settings.touch_mode, "mouse motion right after a touch: still touch mode")

	# a real mouse takes over: no finger for a second, then real movement
	await create_timer(1.2).timeout
	for i in 4:
		await mouse_move(Vector2(30, 0))
	await frames(2)
	check(not settings.touch_mode, "real mouse movement: back to mouse mode")
	for i in 3:  # mouse motion is accumulated and delivered late in the frame
		await process_frame
	check(not tc.visible, "controls hidden in mouse mode")

	print("RESULT fails=%d" % fails)
	room.queue_free()
	await process_frame
	quit()
