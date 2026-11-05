extends SceneTree
# Debug menu (studio spec 13, build step 9): F1 opens it (debug builds), lists chapters and
# the level's checkpoints, jumps to them, noclip, FPS, trigger boxes, give items, AI off/on.
# Run: <console exe> --path . --quit-after 60000 --script res://tests/test_debug_menu.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _initialize() -> void:
	await process_frame
	var game = root.get_node("GameManager")
	var settings = root.get_node("SettingsManager")
	game.save_path = "user://test_debug_save.json"
	game.delete_save()
	var old_fps = settings.show_fps
	var menu = root.get_node_or_null("DebugMenu")
	check(menu != null, "DebugMenu autoload is there in a debug build")
	if menu == null:
		quit(1)
		return

	change_scene_to_file("res://tests/scenes/test_room.tscn")
	await frames(5)
	var p = get_first_node_in_group("player")

	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	menu._unhandled_key_input(f1)
	check(menu.is_open and menu._panel.visible, "F1 opens the menu")
	check(not root.get_node("InputManager").mouse_captured(), "the mouse is free while it's open")
	var buttons := 0
	for c in menu._list.get_children():
		if c is BaseButton:
			buttons += 1
	check(buttons >= 8, "chapters, checkpoints and cheats listed (%d buttons)" % buttons)

	var cps: Array = menu.checkpoints()
	check(cps.size() == 3, "the level's three checkpoints are listed")
	var storage = cps.filter(func(c): return c.name == "Storage")[0]
	menu.jump_to_checkpoint(storage)
	await frames(2)
	check(p.global_position.distance_to(storage.global_position) < 0.2, "GO TO puts the player at the checkpoint")

	menu.set_noclip(true)
	check(p.noclip and p._collider.disabled, "noclip: collision off")
	p.global_position += Vector3(0, 3, 0)
	var y: float = p.global_position.y
	await wait(0.5)
	check(absf(p.global_position.y - y) < 0.01, "noclip: no gravity, hangs in the air")
	menu.set_noclip(false)
	check(not p._collider.disabled, "noclip off: solid again")

	menu.set_show_fps(true)
	check(settings.show_fps, "SHOW FPS turns the counter on")
	settings.show_fps = old_fps

	menu.set_show_triggers(true)
	await frames(2)
	check(menu.trigger_count() >= 4, "SHOW TRIGGERS draws the zones (%d)" % menu.trigger_count())
	menu.set_show_triggers(false)
	await frames(2)
	check(menu.trigger_count() == 0, "and hides them again")

	menu.give_item(&"dbg_key", "Debug key")
	check(game.has_item(&"dbg_key") and root.get_node("EventBus").has_fired(&"dbg_key"),
		"GIVE adds the item and fires its event")

	menu.toggle()
	check(not menu.is_open, "F1 again closes it")

	# AI toggle + chapter jump on Tape 1
	game.chapter_complete_wait = 0.3
	check(menu.jump_to_chapter(&"tape_01_watchman"), "jump to Tape 1")
	await game.transition_finished
	await frames(3)
	var lv = current_scene
	lv.get_node("Story").time_scale = 0.05
	var stalker = lv.get_node("Stalker/Brain")
	menu.set_ai(false)
	check(stalker.process_mode == Node.PROCESS_MODE_DISABLED and lv.get_node("Deshmukh").process_mode == Node.PROCESS_MODE_DISABLED,
		"AI off: the Stalker and the walkers stop")
	menu.set_ai(true)
	check(stalker.process_mode == Node.PROCESS_MODE_INHERIT, "AI on again")
	check(not menu.noclip and menu.ai_enabled, "toggles reset with the new level")

	game.delete_save()
	current_scene.queue_free()
	await frames(5)
	print("RESULT fails=", fails)
	quit(fails)
