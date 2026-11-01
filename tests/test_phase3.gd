extends SceneTree
# Phase 3 interaction: footsteps by surface, drawers (slide, contents ride along, lock +
# unlock event, remembered), inspecting items (close-up view, turn, put back, take).
# Uses Tape 1's cabin. Separate save file.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_phase3.gd

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
	var events: Node = root.get_node("Events")
	game.save_path = "user://test_save.json"
	game.delete_save()
	check(game.start_chapter(&"tape_01_watchman"), "tape 1 starts")
	await game.transition_finished
	var lv: Node = current_scene
	var p = get_first_node_in_group("player")
	lv.get_node("Story").time_scale = 0.01
	var steps = p.get_node("Footsteps")

	# --- Footsteps by surface ---
	for spot in [[Vector3(5.75, 0.1, 23.6), &"tile", "cabin's Kota floor"], [Vector3(0, 0.1, 2), &"concrete", "courtyard pavers"],
			[Vector3(-12.5, 12.1, -15.0), &"tile", "B wing 4th-floor landing"]]:
		p.global_position = spot[0]
		p.velocity = Vector3.ZERO
		await physics(6)
		var s: StringName = steps.surface_under()
		check(s == spot[1], "footsteps on %s sound like %s (got %s)" % [spot[2], spot[1], s])
	p.global_position = Vector3(0, 0.1, 2)
	await physics(4)
	var before: int = steps.steps_taken
	for i in 60:
		p.velocity = Vector3(2.4, 0, 0)  # walking pace
		steps._physics_process(1.0 / 60.0)
	check(steps.steps_taken - before == 3, "first step soon after moving off, then one per 0.72 m (%d steps over 2.4 m)" % (steps.steps_taken - before))
	p.velocity = Vector3.ZERO

	# --- Drawer in the watchman's table ---
	p.global_position = Vector3(6.35, 0.05, 23.9)
	await physics(4)
	var drawer = lv.get_node("TableDrawer")
	var card = lv.get_node("TableDrawer/KishanID")
	var closed_z: float = drawer.global_position.z
	var card_z: float = card.global_position.z
	drawer.get_node("Interactable").interact(p)
	await create_timer(0.5).timeout
	check(drawer.is_open and drawer.global_position.z < closed_z - 0.3, "drawer slides out towards Raghu (%.2f m)" % (closed_z - drawer.global_position.z))
	check(absf((card_z - card.global_position.z) - (closed_z - drawer.global_position.z)) < 0.01, "the ID card rides along inside")
	check(drawer.get_node("Interactable").prompt == "Close drawer", "prompt flips to Close drawer")

	# --- Inspect the card (look only) ---
	var view = lv.get_node("HUD/InspectView")
	card.get_node("Interactable").interact(p)
	await physics(2)
	check(view.is_open and not p.input_enabled, "ID card opens the close-up view, player frozen")
	check(view._title.text == "Kishan's ID card" and view._text.text.contains("cut the photo out"), "title + description shown")
	var meshes: int = view._pivot.find_children("*", "MeshInstance3D", true, false).size()
	check(meshes >= 2 and view._pivot.find_children("*", "Area3D", true, false).is_empty(), "a visual copy only (%d meshes, no areas)" % meshes)
	var basis_before: Basis = view._pivot.basis
	view.turn(Vector2(0.8, 0.3))
	check(not view._pivot.basis.is_equal_approx(basis_before), "dragging turns it over")
	check(events.has_fired(&"kishan_card"), "inspected_event fired")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics(3)
	check(not view.is_open and p.input_enabled and is_instance_valid(card), "E puts it back (it can't be taken)")

	# --- The battery in the drawer ---
	lv.get_node("TableDrawer/Battery/Interactable").interact(p)
	await physics(2)
	check(events.has_fired(&"battery"), "spare camcorder battery taken from the drawer")
	drawer.get_node("Interactable").interact(p)
	await create_timer(0.5).timeout
	check(not drawer.is_open and absf(drawer.global_position.z - closed_z) < 0.01, "drawer closes")

	# --- A takeable inspectable + a locked drawer (built in code) ---
	var item := Node3D.new()
	item.name = "Lighter"
	var model := Node3D.new()
	model.name = "Model"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(0.02, 0.06, 0.012)
	model.add_child(mesh)
	item.add_child(model)
	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load("res://scripts/interaction/interactable.gd"))
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	area.add_child(shape)
	item.add_child(area)
	item.set_script(load("res://scripts/interaction/inspectable.gd"))
	item.set(&"title", "Lighter")
	item.set(&"item_id", &"lighter")
	lv.add_child(item)
	item.owner = lv
	item.global_position = Vector3(5.5, 0.9, 24.0)
	await physics(2)
	item.open()
	await physics(2)
	check(view.is_open and view._hint.text.begins_with("[E] Take"), "takeable item offers [E] Take")
	view.close(true)
	await physics(2)
	check(events.has_fired(&"lighter") and not is_instance_valid(item) and game.get_flag("picked:Lighter", false), "taking it fires its item id, it's gone and remembered")

	var locked = load("res://scenes/props/drawer.tscn").instantiate()
	locked.set(&"locked", true)
	locked.set(&"unlock_event", &"desk_key")
	lv.add_child(locked)
	locked.global_position = Vector3(5.0, 0.6, 24.0)
	await physics(2)
	locked.get_node("Interactable").interact(p)
	await create_timer(0.4).timeout
	check(not locked.is_open, "locked drawer stays shut (rattles)")
	events.fire(&"desk_key")
	locked.get_node("Interactable").interact(p)
	await create_timer(0.4).timeout
	check(locked.is_open, "unlock event opens the lock")

	game.delete_save()
	current_scene.queue_free()
	await physics(3)
	print("RESULT fails=", fails)
	quit(fails)
