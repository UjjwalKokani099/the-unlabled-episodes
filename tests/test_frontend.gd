extends SceneTree
# Front end (studio spec step 4): boot (studio card -> content warning -> any key -> main
# menu), the main menu drone fading in and the version label, loading card (reels +
# progress + an in-world tip with the player's keys; plain fades stay plain), tape preview
# (snow before a tape is watched, the checkpoint still after), credits roll, pause menu
# asking before leaving a tape. Separate save file.
# Run: <console exe> --path . --quit-after 9000 --script res://tests/test_frontend.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	await process_frame
	var game = root.get_node("GameManager")
	var loader = root.get_node("SceneLoader")
	var audio = root.get_node("AudioManager")
	game.save_path = "user://test_save.json"
	game.delete_save()
	game.mark_intro_seen()

	# --- boot
	change_scene_to_file("res://ui/menus/boot.tscn")
	await scene_changed
	var boot: Node = current_scene
	check(boot.stage == 0 and boot._sting.playing, "boot: studio card with its sting")
	await create_timer(0.8).timeout
	check(boot._studio.modulate.a > 0.2, "studio card fades in from black")
	var waited := 0.8
	while boot.stage == 0 and waited < 5.0:
		await process_frame
		waited += 1.0 / 60.0
	check(boot.stage == 1 and boot._warning.visible and boot._warning_time < 0.2, "after the card: content warning")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	check(boot.stage == 1, "a key in the first moment is ignored (no accidental skip)")
	await create_timer(0.7).timeout
	Input.parse_input_event(key)
	await frames(2)
	check(boot.stage == 2, "any key: on to the main menu")
	await loader.transition_finished
	var menu: Node = current_scene
	check(menu.name == "MainMenu", "main menu after boot")

	# --- menu drone + version
	var music: AudioStreamPlayer = audio.get_node("Music")
	var db0 := music.volume_db
	await create_timer(1.5).timeout
	check(music.playing and music.stream.resource_path.ends_with("menu_drone.ogg"), "menu drone playing")
	check(db0 < -30.0 and music.volume_db > db0 + 5.0 and music.volume_db < -4.5, "drone fades in slowly (%.0f -> %.0f dB)" % [db0, music.volume_db])
	check(menu.get_node("Version").text == "v0.1.0", "version in the corner (%s)" % menu.get_node("Version").text)

	# --- tapes preview: never watched = snow
	menu.get_node("Screen/UI/Panel/VBox/List/Tapes").pressed.emit()
	await frames(2)
	var preview := "Screen/UI/TapesPanel/VBox/Body/Preview/"
	check(menu.get_node(preview + "Picture/Snow").visible and menu.get_node(preview + "Status").text.contains("NOT WATCHED"),
		"unwatched tape: snow + NOT WATCHED")
	check(menu.get_node(preview + "Status").text.contains("SPOTTED 0/3"), "sightings counter (%s)" % menu.get_node(preview + "Status").text)

	# --- credits
	menu._back_to_main()
	menu.get_node("Screen/UI/Panel/VBox/List/Credits").pressed.emit()
	await create_timer(2.0).timeout
	var credits = menu.get_node("Screen/UI/Credits")
	check(credits.visible and credits.line_count() > 40, "credits roll open (%d lines)" % credits.line_count())
	check(credits.scroll.scroll_vertical > 0, "credits roll upward")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	check(not credits.visible and menu.get_node("Screen/UI/Panel").visible, "Esc leaves the credits")

	# --- tips
	var tips = load("res://ui/hud/loading_tips.gd")
	var seen := {}
	for i in 30:
		seen[tips.pick("res://chapters/chapter_01/shanti_vihar.tscn")] = true
	check(seen.size() > 5 and not seen.has(""), "tips vary (%d different)" % seen.size())
	var hub_only := false
	for t in seen:
		if "Maa" in t:
			hub_only = true
	check(not hub_only, "hub-only tips don't show for tape 1")
	check(tips.fill_keys("press {spot}") == "press [%s]" % root.get_node("SettingsManager").key_name(&"spot"), "tips show the player's key")

	# --- loading card on a tape + the checkpoint still
	audio.stop_music(0.1)
	game.start_chapter(&"tape_00_test")
	var card = loader.transition()
	for i in 600:
		if card._header.visible:
			break
		await process_frame
	check(card._tip.visible and card.tip_text() != "" and card._reels.visible, "tape card: tip + reels ('%s')" % card.tip_text())
	await game.transition_finished
	check(card._reels.progress == 1.0, "progress reached 100%")
	game.save_checkpoint(&"start")
	await frames(6)
	check(FileAccess.file_exists("user://thumbs/tape_00_test.png"), "checkpoint keeps a still of the picture")
	var still = game.chapter_thumbnail(&"tape_00_test")
	check(still != null and still.get_width() == 352 and still.get_height() == 264, "still is 4:3 352x264")

	# --- pause: leaving asks first
	var pm = current_scene.get_node("HUD/PauseMenu")
	pm.open()
	pm.get_node("Root/List/Eject").pressed.emit()
	check(pm.confirm.visible and pm.confirm.no_button.has_focus(), "eject asks, NO focused")
	pm.confirm.no_button.pressed.emit()
	check(not pm.confirm.visible and pm.get_node("Root/List").visible and pm.is_open, "NO: back to the pause list")
	pm.close()

	# --- plain fade stays plain
	game.go_to_main_menu()
	for i in 600:
		if card._header.visible:
			break
		await process_frame
	check(card._header.visible and not card._tip.visible and not card._reels.visible, "plain fade: no tip, no reels")
	while loader.is_transitioning():
		await process_frame

	game.delete_save()
	check(not FileAccess.file_exists("user://thumbs/tape_00_test.png"), "deleting the save removes the stills")
	game.save_path = root.get_node("SaveManager").DEFAULT_PATH
	audio.stop_music(0.1)
	current_scene.queue_free()
	await frames(5)
	print("RESULT fails=%d" % fails)
	quit()
