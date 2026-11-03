extends SceneTree
# Objectives: chaining, counters, past events, completion events; then a full test-room run.
# Run: <console exe> --path . --quit-after 4000 --script res://tests/test_objectives.gd

const ObjectiveDataScript = preload("res://systems/objectives/objective_data.gd")
const ObjectiveSetScript = preload("res://systems/objectives/objective_set.gd")

var fails := 0
var p
var room: Node
var events: Node
var objectives: Node

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func make(id: StringName, on: StringName, required := 1, after: StringName = &""):
	var o = ObjectiveDataScript.new()
	o.id = id
	o.text = String(id)
	o.complete_on = on
	o.required = required
	o.starts_after = after
	return o

func active_ids() -> Array:
	return objectives.get_active().map(func(o): return String(o.id))

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

func focused_prompt() -> String:
	var f = p.interactor.focused
	return f.prompt if f else "<nothing>"

func panel_lines() -> Array:
	return room.get_node("HUD/Objectives").get_children().map(func(l): return l.text)

func _initialize() -> void:
	await process_frame  # let autoloads run _ready (Objectives subscribes to Events there)
	events = root.get_node("EventBus")
	objectives = root.get_node("ObjectiveManager")
	var finished := [0]
	objectives.all_completed.connect(func(): finished[0] += 1)

	# --- Logic with a hand-built set ---
	events.reset()
	var set = ObjectiveSetScript.new()
	set.objectives.append(make(&"a", &"ev_a"))
	set.objectives.append(make(&"b", &"ev_b", 2, &"a"))
	events.fire(&"ev_b")  # happens before "b" is active
	objectives.begin(set)
	check(active_ids() == ["a"], "only 'a' active at start (%s)" % [active_ids()])
	events.fire(&"ev_x")
	check(active_ids() == ["a"], "unrelated event changes nothing")
	events.fire(&"ev_a")
	check(objectives.is_completed(&"a") and active_ids() == ["b"], "'a' done, 'b' starts")
	check(events.has_fired(&"a"), "completed objective fires its id as an event")
	check(objectives.get_progress(&"b") == 1, "earlier ev_b counted when 'b' started (%d)" % objectives.get_progress(&"b"))
	check(finished[0] == 0, "not finished yet")
	events.fire(&"ev_b")
	check(objectives.is_completed(&"b") and active_ids().is_empty(), "'b' done at 2/2")
	check(finished[0] == 1, "all_completed fired exactly once")
	events.fire(&"ev_b")
	check(objectives.get_progress(&"b") == 2, "no progress after completion")
	finished[0] = 0

	# --- Full run in the test room ---
	room = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	p = room.get_node("Player")
	await frames(20)
	check(active_ids() == ["find_tape"], "room starts with find_tape (%s)" % [active_ids()])
	check(panel_lines() == ["Find the tape in the dark room"], "HUD panel lists it (%s)" % [panel_lines()])
	check(room.get_node("HUD/Objectives").modulate.a > 0.5, "panel visible after objective appears")
	var storage = room.get_node("LockedDoor")
	check(storage.locked, "storage door locked")

	await stand_at(Vector3(5, 0, -7.6), 0, -5)
	await send_interact(true)
	await frames(75)
	await send_interact(false)
	check(objectives.is_completed(&"find_tape") and active_ids() == ["open_storage"], "tape -> open_storage (%s)" % [active_ids()])
	check(not storage.locked, "storage door unlocked by find_tape")
	check(panel_lines() == ["Find the tape in the dark room  - done", "Get into the storage room"], "panel shows done + new (%s)" % [panel_lines()])

	await stand_at(Vector3(8, 0, -11.0), 0, 0)
	await send_interact(true)
	await send_interact(false)
	await frames(60)
	check(storage.is_open, "storage door opens")
	check(active_ids() == ["collect_batteries"], "-> collect_batteries (%s)" % [active_ids()])
	check(panel_lines().has("Collect batteries  0/3"), "counter 0/3 shown (%s)" % [panel_lines()])

	var n := 0
	for x in [7.4, 8.0, 8.6]:
		await stand_at(Vector3(x, 0, -14.6), 0, -32)
		var prompt := focused_prompt()
		await send_interact(true)
		await send_interact(false)
		await frames(3)
		n += 1
		if n < 3:
			check(objectives.get_progress(&"collect_batteries") == n, "battery %d (prompt '%s', progress %d)" % [n, prompt, objectives.get_progress(&"collect_batteries")])
	check(objectives.is_completed(&"collect_batteries"), "all 3 batteries collected")
	check(active_ids() == ["return_to_start"], "-> return_to_start (%s)" % [active_ids()])
	check(panel_lines().has("Collect batteries  - done"), "panel shows batteries done (%s)" % [panel_lines()])
	await create_timer(3.0).timeout
	check(panel_lines() == ["Go back to where you started"], "done lines expire (%s)" % [panel_lines()])
	events.fire(&"test_exit")
	check(finished[0] == 1, "test room objectives all completed")

	print("RESULT fails=", fails)
	quit(fails)
