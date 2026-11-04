extends SceneTree
# Interaction feel (studio spec): 2.0 m reach, the prompt fades in over ~0.15 s instead of
# popping, the crosshair pulses on use, and nothing happens silently: door creak on open,
# creak + latch on close, rattle + camera nudge when locked, switch click. Test room.
# Run: <console exe> --path . --quit-after 6000 --script res://tests/test_interaction_feel.gd

var fails := 0
var room: Node
var p
var audio


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


func tap_interact() -> void:
	Input.action_press("interact")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	Input.action_release("interact")
	var up := InputEventAction.new()
	up.action = &"interact"
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


## Stream paths of every pooled 3D one-shot playing right now.
func playing() -> Array:
	var out := []
	for child in audio.get_children():
		if child is AudioStreamPlayer3D and child.playing and child.stream:
			out.append(child.stream.resource_path)
	return out


func playing_any(prefix: String) -> bool:
	for path in playing():
		if prefix in path:
			return true
	return false


func _initialize() -> void:
	await process_frame
	audio = root.get_node("AudioManager")
	room = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	p = room.get_node("Player")
	await frames(30)
	var prompt: Label = room.get_node("HUD/Prompt")
	var crosshair = room.get_node("HUD/Crosshair")

	check(is_equal_approx(p.interactor.target_position.length(), 2.0), "interaction reach 2.0 m")

	# --- prompt fades in, not a pop
	var door = room.get_node("Door")
	await stand_at(Vector3(6, 0, -1.0), 0, 0)
	check(not prompt.visible, "no prompt when nothing is in reach")
	await stand_at(Vector3(6, 0, -2.5), 0, 0)
	var first_alpha: float = prompt.modulate.a
	await create_timer(0.25).timeout
	check(prompt.visible and first_alpha < 0.9 and prompt.modulate.a > 0.95,
		"prompt fades in (alpha %.2f -> %.2f)" % [first_alpha, prompt.modulate.a])

	# --- door: creak on open, crosshair pulse
	await tap_interact()
	check(crosshair._pulse > 0.0, "crosshair pulses on use")
	check(playing_any("door_creak"), "door open: hinge creak (%s)" % [playing()])
	await create_timer(1.0).timeout
	await tap_interact()
	check(playing_any("door_creak"), "door close: creak")
	await create_timer(0.9).timeout
	check(not door.is_open and playing_any("door_latch"), "door close: latch clicks home")
	await create_timer(0.6).timeout

	# --- locked: rattle + small camera nudge
	door.lock()
	var shake = p.get_node("Head/Camera3D/CameraShake")
	shake.trauma = 0.0
	await tap_interact()
	check(playing_any("door_rattle"), "locked door: rattle")
	check(shake.trauma > 0.05, "locked door: camera nudge (trauma %.2f)" % shake.trauma)
	door.unlock()
	await create_timer(0.6).timeout

	# --- light switch click
	var switch = room.get_node("LightSwitch")
	var was_on: bool = switch.is_on
	switch.set_on(not was_on)
	check(playing_any("switch_click"), "light switch: click")
	switch.set_on(was_on)

	room.queue_free()
	await frames(3)
	print("RESULT fails=%d" % fails)
	quit()
