extends SceneTree
# VCR main menu (continue/new game/tapes/settings tabs + rebinding), pause menu, through a
# session. Separate save file; restores the player's settings afterwards.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_menus.gd

var fails := 0
var game: Node
var settings: Node

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await process_frame

func send_action(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(2)

func pause_menu():
	return current_scene.get_node("HUD/PauseMenu")

## New game may play the intro first; skip it to reach the hub.
func await_hub() -> void:
	await game.transition_finished
	if current_scene.name == "Intro":
		current_scene.skip()
		await game.transition_finished

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	var saved_settings := {}
	for key in settings.KEYS:
		saved_settings[key] = settings.get(key)
	game.save_path = "user://test_save.json"
	game.delete_save()
	game.mark_intro_seen()

	# --- Main menu, fresh save ---
	change_scene_to_file("res://scenes/menus/main_menu.tscn")
	await scene_changed
	await frames(5)
	var menu: Node = current_scene
	var list := "Panel/VBox/List/"
	check(not menu.get_node(list + "Continue").visible, "fresh save: no Continue")
	check(root.gui_get_focus_owner() == menu.get_node(list + "NewGame"), "NEW GAME focused")

	# --- Tapes: tape 1 playable entry, the rest blank cassettes ---
	menu.get_node(list + "Tapes").pressed.emit()
	var tapes: Array = menu.get_node("TapesPanel/VBox/List").get_children().filter(func(n): return n is Button)
	check(tapes.size() == 6, "5 tapes + back (%d)" % tapes.size())
	check(not tapes[0].disabled and tapes[0].text.contains("THE WATCHMAN"), "tape 1 listed ('%s')" % tapes[0].text)
	check(tapes.slice(1, 5).all(func(b): return b.disabled and b.text.begins_with("□")), "locked tapes are blank cassettes")
	await send_action(&"ui_cancel")
	check(menu.get_node("Panel").visible and not menu.get_node("TapesPanel").visible, "Esc back from tapes")

	# --- Settings tabs + rebinding ---
	menu.get_node(list + "Settings").pressed.emit()
	var sm = menu.get_node("Settings")
	check(sm.visible, "settings open")
	sm.show_tab(2)
	check(sm.controls[&"mouse_sensitivity"].visible and not sm.controls[&"brightness"].visible, "controls tab shows only its rows")
	sm.controls[&"mouse_sensitivity"].value = 0.3
	check(is_equal_approx(settings.mouse_sensitivity, 0.3), "slider sets sensitivity")
	sm.controls[&"flashlight"].pressed.emit()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	check(settings.key_name(&"flashlight") == "G" and settings.key_bindings.get("flashlight") == KEY_G, "flashlight rebound to G")
	settings.key_bindings = {}
	InputMap.load_from_project_settings()
	sm.show_tab(3)
	check(sm.controls[&"subtitles"].visible, "subtitles tab")
	sm.show_tab(0)
	sm.controls[&"brightness"].value = 1.3
	check(settings._brightness_rect.visible, "brightness overlay on above 1.0")
	sm.controls[&"brightness"].value = 1.0
	await send_action(&"ui_cancel")
	check(not sm.visible and menu.get_node("Panel").visible, "Esc closes settings")

	# --- Into a tape, pause menu ---
	game.start_chapter(&"tape_00_test")
	await game.transition_finished
	await frames(20)
	await send_action(&"pause")
	var pm = pause_menu()
	check(paused and pm.is_open and pm.get_node("Root/List/Restart").visible, "paused in a tape, restart offered")
	pm.get_node("Root/List/MainMenu").pressed.emit()
	await game.transition_finished
	menu = current_scene
	check(menu.name == "MainMenu" and menu.get_node(list + "Continue").visible, "main menu offers Continue")
	menu.get_node(list + "Continue").pressed.emit()
	await game.transition_finished
	check(current_scene.name == "TestRoom", "Continue resumes the tape")

	# --- New game erases (after confirming) ---
	await send_action(&"pause")
	pause_menu().get_node("Root/List/MainMenu").pressed.emit()
	await game.transition_finished
	menu = current_scene
	menu.get_node(list + "NewGame").pressed.emit()
	check(menu.get_node("Confirm").visible, "confirm shown")
	await send_action(&"ui_cancel")
	check(not menu.get_node("Confirm").visible and game.has_progress(), "Esc cancels, save kept")
	menu.get_node(list + "NewGame").pressed.emit()
	menu.get_node("Confirm/Panel/VBox/List/Yes").pressed.emit()
	await await_hub()
	check(current_scene.name == "Hub" and not game.has_progress(), "YES erases progress, ends in the hub")

	for k in saved_settings:
		settings.set(k, saved_settings[k])
	game.delete_save()
	current_scene.queue_free()
	await frames(3)
	print("RESULT fails=", fails)
	quit(fails)
