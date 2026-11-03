extends SceneTree
# Trigger zones + reactions, using the test room's three scares.
# Run: <console exe> --path . --quit-after 4000 --script res://tests/test_events.gd

var fails := 0
var p
var room: Node
var events: Node

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func seconds(s: float) -> void:
	await frames(int(s * 60.0))

func teleport(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await frames(4)

func _initialize() -> void:
	await process_frame
	events = root.get_node("EventBus")
	room = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	p = room.get_node("Player")
	await frames(20)
	var light: Light3D = room.get_node("RoomLight")
	var base_energy := light.light_energy
	var flicker = room.get_node("Scares/DarkRoomFlicker")
	var knock: AudioStreamPlayer3D = room.get_node("Scares/DarkRoomKnock/Knock")

	# --- Scare 1: entering the dark room ---
	check(not events.has_fired(&"entered_dark_room"), "zone silent before entering")
	await teleport(Vector3(6, 0, -6))
	check(events.count(&"entered_dark_room") == 1, "entering dark room fires event")
	var min_energy := base_energy
	var saw_flicker := false
	for i in 60:  # ~1 s
		await physics_frame
		min_energy = minf(min_energy, light.light_energy)
		saw_flicker = saw_flicker or flicker.is_flickering
	check(saw_flicker and min_energy < base_energy * 0.5, "room light flickers (min energy %.2f)" % min_energy)
	check(light.visible, "flicker never toggles the light's on/off state")
	await seconds(0.8)
	check(knock.playing, "knock plays ~1.8 s after entering")
	await seconds(1.0)
	check(not flicker.is_flickering and is_equal_approx(light.light_energy, base_energy), "light energy restored")
	await teleport(Vector3(6, 0, -2))
	await teleport(Vector3(6, 0, -6))
	check(events.count(&"entered_dark_room") == 1, "once-only zone doesn't refire")

	# Player switches the light off mid-flicker: their choice must stick.
	flicker.trigger()
	await seconds(0.4)
	room.get_node("LightSwitch").set_on(false)
	await seconds(1.4)
	check(not light.visible and is_equal_approx(light.light_energy, base_energy), "switch-off during flicker sticks")
	room.get_node("LightSwitch").set_on(true)

	# --- Scare 2: tape pickup slams the divider door ---
	var door = room.get_node("Door")
	check(door.slam() == false, "slam on a closed door does nothing")
	door.open_away_from(Vector3(6, 0, -2.5))
	await seconds(1.0)
	events.fire(&"vhs_tape")
	await seconds(1.0)
	check(door.is_open, "door still open 1 s after the tape")
	await seconds(0.7)
	check(not door.is_open and absf(door.hinge.rotation.y) < 0.02, "door slammed shut ~1.5 s after the tape")
	check(door._slam_player != null and door._slam_player.playing, "slam sound plays")

	# --- Scare 3: armed zone, figure + flashlight flicker + sting ---
	var figure: Node3D = room.get_node("Scares/Figure")
	var flashlight: SpotLight3D = p.flashlight
	var torch_energy := flashlight.light_energy
	await teleport(Vector3(8, 0, -11))
	check(not events.has_fired(&"left_storage"), "storage exit zone ignored before batteries")
	events.fire(&"collect_batteries")  # arms it while the player is standing inside
	await frames(2)
	check(events.has_fired(&"left_storage"), "arming while inside fires immediately")
	check(figure.visible, "figure appears")
	check(room.get_node("Scares/FigureSting/Sting").playing, "sting plays")
	var torch_min := torch_energy
	for i in 50:
		await physics_frame
		torch_min = minf(torch_min, flashlight.light_energy)
	check(torch_min < torch_energy * 0.5, "flashlight flickers")
	await seconds(0.8)
	check(not figure.visible, "figure gone after 1.3 s")
	check(flashlight.visible and is_equal_approx(flashlight.light_energy, torch_energy), "flashlight back to normal")

	room.queue_free()  # stop sounds before quitting (playing audio at exit reports leaks)
	await frames(3)
	print("RESULT fails=", fails)
	quit(fails)
