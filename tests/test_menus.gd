extends SceneTree
# Main menu, settings screen and pause menu, through a full session. Uses a separate save
# file and restores the player's settings afterwards.
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
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(1)

func focused() -> Control:
	return root.gui_get_focus_owner()

func pause_menu():
	return current_scene.get_node("HUD/PauseMenu")

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	var saved_settings := {}
	for key in settings.KEYS:
		saved_settings[key] = settings.get(key)
	game.save_path = "user://test_save.json"
	game.delete_save()

	# --- Main menu, fresh save ---
	change_scene_to_file("res://scenes/menus/main_menu.tscn")
	await scene_changed
	await frames(5)
	var menu: Node = current_scene
	check(not menu.get_node("List/Continue").visible and not menu.get_node("List/NewGame").visible, "fresh save: no Continue / New Game")
	check(menu.get_node("List/Tapes").text == "START", "START shown")
	check(focused() == menu.get_node("List/Tapes"), "START has keyboard focus")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse visible in menu")

	# --- Settings screen ---
	menu.get_node("List/Settings").pressed.emit()
	var sm = menu.get_node("Settings")
	check(sm.visible and not menu.get_node("List").visible, "settings open, list hidden")
	sm.controls[&"mouse_sensitivity"].value = 0.3
	check(is_equal_approx(settings.mouse_sensitivity, 0.3), "slider sets sensitivity")
	sm.controls[&"invert_y"].button_pressed = true
	check(settings.invert_y, "toggle sets invert Y")
	sm.controls[&"brightness"].value = 1.3
	check(settings._brightness_rect.visible, "brightness overlay on above 1.0")
	sm.controls[&"brightness"].value = 1.0
	check(not settings._brightness_rect.visible, "brightness overlay off at 1.0")
	await send_action(&"ui_cancel")
	check(not sm.visible and menu.get_node("List").visible, "Esc closes settings")
	check(focused() == menu.get_node("List/Settings"), "focus back on SETTINGS")

	# --- START -> hub ---
	menu.get_node("List/Tapes").pressed.emit()
	await game.transition_finished
	check(current_scene.name == "Hub", "START goes to the hub")

	# --- Pause in the hub ---
	await send_action(&"pause")
	var pm = pause_menu()
	check(paused and pm.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc pauses, mouse freed")
	check(not pm.get_node("Root/List/Restart").visible and not pm.get_node("Root/List/Eject").visible, "hub: no restart/eject")
	check(focused() == pm.get_node("Root/List/Resume"), "RESUME focused")
	await send_action(&"pause")
	check(not paused and not pm.is_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Esc again resumes")

	# --- Pause in a tape ---
	game.start_chapter(&"tape_00_test")
	await game.transition_finished
	await frames(20)
	await send_action(&"pause")
	pm = pause_menu()
	check(pm.get_node("Root/List/Restart").visible and pm.get_node("Root/List/Eject").visible, "tape: restart + eject shown")
	check(pm.get_node("Root/Where").text == "TEST TAPE - GREY ROOM", "shows which tape")
	pm.get_node("Root/List/Settings").pressed.emit()
	check(pm.get_node("Root/Settings").visible, "settings from pause")
	await send_action(&"pause")
	check(not pm.get_node("Root/Settings").visible and pm.is_open and paused, "Esc closes settings but stays paused")
	pm.get_node("Root/List/Restart").pressed.emit()
	await game.transition_finished
	check(current_scene.name == "TestRoom" and not paused and not pause_menu().is_open, "restart from checkpoint")

	# --- Main menu with progress -> Continue ---
	await send_action(&"pause")
	pause_menu().get_node("Root/List/MainMenu").pressed.emit()
	await game.transition_finished
	menu = current_scene
	check(menu.name == "MainMenu" and game.current_chapter == null, "back at main menu")
	check(menu.get_node("List/Continue").visible and menu.get_node("List/Continue").text == "CONTINUE  TEST TAPE", "Continue offered ('%s')" % menu.get_node("List/Continue").text)
	check(menu.get_node("List/NewGame").visible and menu.get_node("List/Tapes").text == "TAPES", "New Game + TAPES shown")
	menu.get_node("List/Continue").pressed.emit()
	await game.transition_finished
	check(current_scene.name == "TestRoom" and game.current_chapter.id == &"tape_00_test", "Continue resumes the tape")

	# --- New game wipes the save (after confirming) ---
	await send_action(&"pause")
	pause_menu().get_node("Root/List/MainMenu").pressed.emit()
	await game.transition_finished
	menu = current_scene
	menu.get_node("List/NewGame").pressed.emit()
	check(menu.get_node("Confirm").visible and focused() == menu.get_node("Confirm/Panel/VBox/List/No"), "confirm shown, NO focused")
	await send_action(&"ui_cancel")
	check(not menu.get_node("Confirm").visible and game.has_progress(), "Esc cancels, save kept")
	menu.get_node("List/NewGame").pressed.emit()
	menu.get_node("Confirm/Panel/VBox/List/Yes").pressed.emit()
	await game.transition_finished
	check(current_scene.name == "Hub" and not game.has_progress(), "YES erases progress, starts in the hub")

	for key in saved_settings:
		settings.set(key, saved_settings[key])
	game.delete_save()
	current_scene.queue_free()
	await frames(3)
	print("RESULT fails=", fails)
	quit(fails)
