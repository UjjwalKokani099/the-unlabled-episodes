extends SceneTree
# The demo, outside in: main menu -> New Game -> intro (skipped) -> the hub (Nikhil's first
# thought) -> tape 1 from the box -> Raghu's opening + a voice-over beat -> checkpoint
# reload (the beat doesn't repeat) -> end of tape -> hub stage 1 (new thought, the diary)
# -> the next tape is the end-of-demo card -> back in the room, nothing repeats.
# Tape 1's own night is covered by test_tape01.gd. Separate save file.
# Run: <console exe> --path . --quit-after 60000 --script res://tests/test_demo.gd

var fails := 0
var game: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func frames(n: int) -> void:
	for i in n:
		await process_frame


func subtitle() -> String:
	var subs = get_first_node_in_group("subtitles")
	return subs._label.text if subs else ""


func clear_subtitle() -> void:
	var subs = get_first_node_in_group("subtitles")
	if subs:
		subs._label.text = ""


## Waits (real time) until the subtitle contains `text`.
func heard(text: String, timeout: float = 8.0) -> bool:
	var t := 0.0
	while not subtitle().contains(text) and t < timeout:
		await wait(0.1)
		t += 0.1
	return subtitle().contains(text)


func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	var settings = root.get_node("SettingsManager")
	var saved_subs: bool = settings.subtitles
	settings.subtitles = true
	game.save_path = "user://test_save.json"
	game.delete_save()
	game.mark_intro_seen()  # the menu would autoplay the intro otherwise
	change_scene_to_file("res://ui/menus/main_menu.tscn")
	await scene_changed
	await frames(5)
	check(current_scene.name == "MainMenu", "main menu is up")

	# --- New Game: intro, then the room
	game.new_game()
	await game.transition_finished
	check(current_scene.scene_file_path.contains("intro"), "New Game plays the intro")
	await wait(1.0)
	game.finish_intro()
	await game.transition_finished
	var hub = current_scene
	check(hub.has_method("use_box") and hub.stage == 0, "skipping the intro lands in Nikhil's room (stage 0)")
	check(await heard("hundred and fifty rupees"), "Nikhil's first thought in the room")

	# --- Tape 1 from the box
	hub.use_box()
	check(hub.held != null and hub.held.chapter_id == &"tape_01_watchman", "the box hands over tape 1")
	hub.use_vcr()
	await game.transition_finished
	var lv = current_scene
	check(game.current_chapter != null and game.current_chapter.id == &"tape_01_watchman", "tape 1 is playing")
	var story = lv.get_node("Story")
	story.time_scale = 0.05
	check(await heard("My name was Raghu", 6.0), "Raghu's opening narration")
	var p = get_first_node_in_group("player")
	clear_subtitle()
	lv.get_node("GateRegister/Interactable").interact(p)
	await frames(2)
	var notes = lv.get_node("HUD/NoteView")
	if notes.is_open:
		notes.close()
	check(await heard("I wrote my name", 6.0), "voice-over beat after signing the register")
	check(game.get_flag("t1_vo_register_signed") == true, "...and it is remembered")

	# --- checkpoint reload: the beat stays said
	game.save_checkpoint(&"start")
	check(game.load_checkpoint(), "reload the checkpoint")
	await game.transition_finished
	lv = current_scene
	lv.get_node("Story").time_scale = 0.05
	clear_subtitle()
	await wait(1.0)
	check(not subtitle().contains("I wrote my name"), "the register beat doesn't replay after a reload")
	check(game.get_flag("t1_vo_register_signed") == true, "its flag survived the checkpoint")

	# --- finish the tape (test_tape01 plays the night itself)
	game.complete_chapter()
	await game.transition_finished
	hub = current_scene
	check(hub.has_method("use_box") and hub.stage == 1, "end of tape: back in the room, stage 1")
	check(await heard("A watchman", 6.0), "Nikhil's thought after tape 1")
	clear_subtitle()
	hub.read_diary()
	check(await heard("not my handwriting", 4.0), "the diary entry isn't his handwriting")
	var note_view = hub.get_node("HUD/NoteView")
	if note_view.is_open:
		note_view.close()

	# --- the next tape = end of the demo
	hub.use_box()
	check(hub.held != null and hub.held.chapter_id == &"tape_02_tollbooth", "the box hands over tape 2")
	hub.use_vcr()
	check(hub.busy, "the VCR takes it")
	await wait(3.0)
	var card = hub.get_node_or_null("DemoEnd")
	check(card != null, "end-of-demo card")
	if card:
		check(card.find_child("Back", true, false) != null, "card offers 'back to the room'")
		card.close()
		await frames(3)
	check(not hub.busy and hub.get_node_or_null("DemoEnd") == null, "back in the room, free to move")

	# --- leave and come back: no repeats
	game.enter_hub()
	await game.transition_finished
	clear_subtitle()
	await wait(4.0)
	check(not subtitle().contains("A watchman"), "Nikhil's thoughts don't repeat on the next visit")
	check(game.remembers("hub_thought_arrival_1") and game.remembers("hub_thought_diary_entry"), "thoughts remembered in the save")

	settings.subtitles = saved_subs
	game.delete_save()
	game.save_path = "user://save.json"
	current_scene.queue_free()
	await frames(2)
	print("RESULT fails=%d" % fails)
	quit()
