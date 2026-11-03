extends SceneTree
# Intro: autoplays on first launch only, can be skipped, ends in the hub, remembers it ran.
# Run: <console exe> --path . --quit-after 20000 --script res://tests/test_intro.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("GameManager")
	game.save_path = "user://test_save.json"
	game.delete_save()
	check(game.should_autoplay_intro(), "first launch: intro autoplays")
	change_scene_to_file("res://ui/menus/main_menu.tscn")
	await scene_changed
	await game.transition_finished
	check(current_scene.name == "Intro", "main menu hands over to the intro")
	await create_timer(4.0).timeout
	check(current_scene.get_node("Camera3D").global_position.z < 4.0, "camera walking through the market")
	current_scene.skip()
	await game.transition_finished
	check(current_scene.name == "Hub", "skipping ends in the hub")
	check(not game.should_autoplay_intro(), "intro remembered as seen")
	game.load_save()
	check(not game.should_autoplay_intro(), "...also after reloading the save")
	game.delete_save()
	current_scene.queue_free()
	await process_frame
	print("RESULT fails=", fails)
	quit(fails)
