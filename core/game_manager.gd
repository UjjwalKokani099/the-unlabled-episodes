extends Node
## Chapter flow, registered as the autoload "GameManager". Decides what goes into the save
## (SaveManager stores it) and asks SceneLoader to change levels.
##
##   GameManager.start_chapter(&"tape_01_watchman")  # fresh start, with the tape card
##   GameManager.load_checkpoint()                    # continue from the last checkpoint
##   GameManager.complete_chapter()                   # "END OF TAPE", unlock next, go to hub
##
## A checkpoint save is: chapter id, checkpoint id, the Events counts, flags (e.g. which
## pickups are gone) and the camcorder clock. Objectives rebuild themselves from the
## Events counts when the level loads, so they don't need saving separately.

## Emitted when a level change has fully finished (screen visible, game unpaused).
## (Forwarded from SceneLoader; chapter/checkpoint news goes out on the EventBus.)
signal transition_finished

const CHAPTER_LIST_PATH := "res://data/chapter_list.tres"
const MAIN_MENU_PATH := "res://ui/menus/main_menu.tscn"
const INTRO_PATH := "res://chapters/intro/intro.tscn"

## Tests point this somewhere else so they never touch the real save (SaveManager's path).
var save_path: String:
	get:
		return SaveManager.save_path
	set(value):
		SaveManager.save_path = value
var chapter_list: ChapterList
## The tape being played, or null (hub, menus, scenes run on their own).
var current_chapter: ChapterData
## Camcorder clock (seconds into the tape) when the current level loaded.
var tape_time_at_load: float = 0.0

var _flags: Dictionary = {}
var _pending_checkpoint: StringName = &""
## Seconds played in the current chapter (paused time doesn't count; kept in checkpoints).
var chapter_play_time: float = 0.0
## Play time of the chapter that was just completed (for the end-of-chapter screen).
var last_chapter_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	chapter_list = load(CHAPTER_LIST_PATH)
	SceneLoader.transition_finished.connect(transition_finished.emit)
	# Closing the window goes through quit_game(), so scripted sequences that are still
	# waiting on timers are freed cleanly (no leaks or errors on exit).
	get_tree().set_auto_accept_quit(false)
	_adopt_current_scene.call_deferred()


# --- Chapters ---------------------------------------------------------------

func get_chapter(id: StringName) -> ChapterData:
	for chapter in chapter_list.chapters + chapter_list.debug_chapters:
		if chapter.id == id:
			return chapter
	return null


func is_completed(id: StringName) -> bool:
	return (SaveManager.data.completed as Array).has(String(id))


func is_unlocked(id: StringName) -> bool:
	var chapters := chapter_list.chapters
	for i in chapters.size():
		if chapters[i].id == id:
			return i == 0 or is_completed(chapters[i - 1].id)
	return get_chapter(id) != null  # debug chapters


func is_transitioning() -> bool:
	return SceneLoader.is_transitioning()


## Starts a chapter from the beginning. Returns false if it can't be started.
func start_chapter(id: StringName) -> bool:
	var chapter := get_chapter(id)
	if chapter == null or not chapter.is_built() or SceneLoader.is_transitioning():
		return false
	current_chapter = chapter
	EventBus.reset()
	_flags = {}
	tape_time_at_load = 0.0
	chapter_play_time = 0.0
	_pending_checkpoint = &""
	SaveManager.data.checkpoint = {}
	SaveManager.write()
	EventBus.chapter_started.emit(chapter)
	_change_level(chapter.scene_path, "PLAY ►", PackedStringArray([chapter.title, chapter.subtitle]))
	return true


func restart_chapter() -> bool:
	return current_chapter != null and start_chapter(current_chapter.id)


# --- Checkpoints ------------------------------------------------------------

func has_checkpoint() -> bool:
	return not (SaveManager.data.checkpoint as Dictionary).is_empty()


## Chapter id of the saved checkpoint (for a "Continue" button), or &"".
func checkpoint_chapter_id() -> StringName:
	return StringName(SaveManager.data.checkpoint.get("chapter", ""))


## Id of the saved checkpoint, or &"".
func saved_checkpoint_id() -> StringName:
	return StringName(SaveManager.data.checkpoint.get("checkpoint", ""))


func save_checkpoint(id: StringName) -> void:
	# Blocked only while the level is still loading behind the tape card (paused). The
	# spawn checkpoint saves as the picture fades in, so "Continue" works right away.
	if current_chapter == null or get_tree().paused:
		return
	SaveManager.data.checkpoint = {
		"chapter": String(current_chapter.id),
		"checkpoint": String(id),
		"events": EventBus.snapshot(),
		"flags": _flags.duplicate(),
		"tape_time": _current_tape_time(),
		"play_time": chapter_play_time,
	}
	SaveManager.write()
	EventBus.checkpoint_saved.emit(id)


## Reloads the level at the last checkpoint. Returns false if there's nothing to load.
func load_checkpoint() -> bool:
	if not has_checkpoint() or SceneLoader.is_transitioning():
		return false
	var saved: Dictionary = SaveManager.data.checkpoint
	var chapter := get_chapter(StringName(saved.chapter))
	if chapter == null or not chapter.is_built():
		return false
	current_chapter = chapter
	EventBus.restore(saved.get("events", {}))
	_flags = (saved.get("flags", {}) as Dictionary).duplicate()
	tape_time_at_load = float(saved.get("tape_time", 0.0))
	chapter_play_time = float(saved.get("play_time", 0.0))
	_pending_checkpoint = StringName(saved.get("checkpoint", ""))
	_change_level(chapter.scene_path, "PLAY ►", PackedStringArray([chapter.title, chapter.subtitle]))
	return true


# --- Completion ---------------------------------------------------------------

func complete_chapter() -> void:
	if current_chapter == null or SceneLoader.is_transitioning():
		return
	var finished := current_chapter
	last_chapter_time = chapter_play_time
	var times: Dictionary = SaveManager.data.get("chapter_times", {})
	times[String(finished.id)] = chapter_play_time
	SaveManager.data["chapter_times"] = times
	if not is_completed(finished.id):
		(SaveManager.data.completed as Array).append(String(finished.id))
	SaveManager.data.checkpoint = {}
	SaveManager.write()
	_clear_chapter_state()
	EventBus.chapter_completed.emit(finished)
	_change_level(_hub_path(), "■ STOP", PackedStringArray([finished.title, "END OF TAPE"]))


## Leave the current tape without finishing it (keeps the checkpoint for Resume).
func return_to_hub() -> void:
	if SceneLoader.is_transitioning():
		return
	var leaving := current_chapter
	_clear_chapter_state()
	_change_level(_hub_path(), "■ STOP", PackedStringArray([leaving.title if leaving else ""]))


## Menu -> hub (plain fade).
func enter_hub() -> void:
	if SceneLoader.is_transitioning():
		return
	_clear_chapter_state()
	_change_level(_hub_path(), "", PackedStringArray())


## Anywhere -> main menu. A tape in progress keeps its checkpoint (Continue).
func go_to_main_menu() -> void:
	if SceneLoader.is_transitioning():
		return
	_clear_chapter_state()
	_change_level(MAIN_MENU_PATH, "■ STOP", PackedStringArray())


## Wipes the save file and starts again with the intro (or the hub if there is none).
func new_game() -> void:
	if SceneLoader.is_transitioning():
		return
	delete_save()
	if ResourceLoader.exists(INTRO_PATH):
		play_intro()
	else:
		enter_hub()


# --- Intro (flea market -> home) ---------------------------------------------

## True only on the very first launch (no save yet, intro never seen).
func should_autoplay_intro() -> bool:
	return not SaveManager.data.get("intro_seen", false) and ResourceLoader.exists(INTRO_PATH)


func mark_intro_seen() -> void:
	SaveManager.data["intro_seen"] = true
	SaveManager.write()


func play_intro() -> void:
	if SceneLoader.is_transitioning():
		return
	_clear_chapter_state()
	_change_level(INTRO_PATH, "PLAY ►", PackedStringArray())


## Called by the intro when it ends or is skipped.
func finish_intro() -> void:
	mark_intro_seen()
	enter_hub()


## Anything worth continuing: a finished tape or a saved checkpoint.
func has_progress() -> bool:
	return not (SaveManager.data.completed as Array).is_empty() or has_checkpoint()


## Quit the game cleanly: save, free the running scene (and any coroutines waiting in it),
## let a frame pass, then quit. The window's close button calls this too.
func quit_game() -> void:
	if SaveManager.data.get("play_time", 0.0) > 0.0:
		SaveManager.write()
	var tree := get_tree()
	tree.paused = false
	# Sounds still playing at exit hold their streams (reported as leaks): stop them all.
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for node in tree.root.find_children("*", type, true, false):
			node.call(&"stop")
	await tree.process_frame
	if tree.current_scene:
		tree.current_scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	tree.quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func _process(delta: float) -> void:
	if current_chapter != null and not get_tree().paused:
		chapter_play_time += delta
		SaveManager.data["play_time"] = float(SaveManager.data.get("play_time", 0.0)) + delta


func _clear_chapter_state() -> void:
	current_chapter = null
	EventBus.reset()
	_flags = {}
	tape_time_at_load = 0.0


# --- Flags (small per-chapter facts that must survive a checkpoint load) ------

func set_flag(key: String, value: Variant = true) -> void:
	_flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return _flags.get(key, default)


# --- Spotting the Cameraman (kept across tapes and replays; all 12 = Ending B) -

## Remembers a spotted appearance. Returns true the first time.
func mark_spotted(spot_id: StringName) -> bool:
	var list: Array = SaveManager.data.get("spotted", [])
	if String(spot_id) in list:
		return false
	list.append(String(spot_id))
	SaveManager.data["spotted"] = list
	SaveManager.write()
	return true


func is_spotted(spot_id: StringName) -> bool:
	return String(spot_id) in (SaveManager.data.get("spotted", []) as Array)


## How many appearances were spotted (ids starting with `prefix`, e.g. "t1_").
func spotted_count(prefix: String = "") -> int:
	var n := 0
	for id: String in SaveManager.data.get("spotted", []):
		if id.begins_with(prefix):
			n += 1
	return n


# --- Memory (one-off moments that must never repeat, e.g. Nikhil's thoughts) ---

## Remembers `key` in the save file (unlike flags, it survives leaving a tape and New Game
## only clears it with the rest of the save). Returns true the first time.
func remember(key: String) -> bool:
	var list: Array = SaveManager.data.get("memory", [])
	if key in list:
		return false
	list.append(key)
	SaveManager.data["memory"] = list
	SaveManager.write()
	return true


func remembers(key: String) -> bool:
	return key in (SaveManager.data.get("memory", []) as Array)


# --- Save file (stored by SaveManager) ------------------------------------------

func load_save() -> void:
	SaveManager.load_save()


func delete_save() -> void:
	SaveManager.delete_save()


# --- Internals ------------------------------------------------------------------

func _change_level(path: String, header: String, lines: PackedStringArray) -> void:
	SceneLoader.change_scene(path, header, lines, _place_player_at_checkpoint)


func _place_player_at_checkpoint() -> void:
	if _pending_checkpoint == &"":
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	for node in get_tree().get_nodes_in_group("checkpoints"):
		var checkpoint := node as Checkpoint
		if checkpoint.checkpoint_id == _pending_checkpoint and player:
			player.teleport(checkpoint.global_transform)
			break
	_pending_checkpoint = &""


func _current_tape_time() -> float:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	return camcorder.osd.elapsed if camcorder else tape_time_at_load


func _hub_path() -> String:
	if chapter_list.hub_scene != "":
		return chapter_list.hub_scene
	return ProjectSettings.get_setting("application/run/main_scene")


## Running a chapter's level directly (F5 / F6 in the editor) still counts as playing it.
func _adopt_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null or current_chapter != null:
		return
	for chapter in chapter_list.chapters + chapter_list.debug_chapters:
		if chapter.scene_path == scene.scene_file_path:
			current_chapter = chapter
			return
