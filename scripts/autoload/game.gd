extends Node
## Chapter flow and save data, registered as the autoload "Game".
##
##   Game.start_chapter(&"tape_01_watchman")  # fresh start, with the tape card
##   Game.load_checkpoint()                    # continue from the last checkpoint
##   Game.complete_chapter()                   # "END OF TAPE", unlock next, go to hub
##
## A checkpoint save is: chapter id, checkpoint id, the Events counts, flags (e.g. which
## pickups are gone) and the camcorder clock. Objectives rebuild themselves from the
## Events counts when the level loads, so they don't need saving separately.

signal chapter_started(chapter: ChapterData)
signal chapter_completed(chapter: ChapterData)
signal checkpoint_saved(id: StringName)
## Emitted when a level change has fully finished (screen visible, game unpaused).
signal transition_finished

const CHAPTER_LIST_PATH := "res://chapters/chapter_list.tres"
const SAVE_VERSION := 1
const TITLE_CARD_SECONDS := 1.4

## Tests point this somewhere else so they never touch the real save.
var save_path: String = "user://save.json"
var chapter_list: ChapterList
## The tape being played, or null (hub, menus, scenes run on their own).
var current_chapter: ChapterData
## Camcorder clock (seconds into the tape) when the current level loaded.
var tape_time_at_load: float = 0.0

var _save: Dictionary = {}
var _flags: Dictionary = {}
var _pending_checkpoint: StringName = &""
var _transitioning: bool = false
var _transition: TapeTransition


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	chapter_list = load(CHAPTER_LIST_PATH)
	_transition = TapeTransition.new()
	add_child(_transition)
	load_save()
	_adopt_current_scene.call_deferred()


# --- Chapters ---------------------------------------------------------------

func get_chapter(id: StringName) -> ChapterData:
	for chapter in chapter_list.chapters + chapter_list.debug_chapters:
		if chapter.id == id:
			return chapter
	return null


func is_completed(id: StringName) -> bool:
	return (_save.completed as Array).has(String(id))


func is_unlocked(id: StringName) -> bool:
	var chapters := chapter_list.chapters
	for i in chapters.size():
		if chapters[i].id == id:
			return i == 0 or is_completed(chapters[i - 1].id)
	return get_chapter(id) != null  # debug chapters


func is_transitioning() -> bool:
	return _transitioning


## Starts a chapter from the beginning. Returns false if it can't be started.
func start_chapter(id: StringName) -> bool:
	var chapter := get_chapter(id)
	if chapter == null or not chapter.is_built() or _transitioning:
		return false
	current_chapter = chapter
	Events.reset()
	_flags = {}
	tape_time_at_load = 0.0
	_pending_checkpoint = &""
	_save.checkpoint = {}
	_write_save()
	chapter_started.emit(chapter)
	_change_level(chapter.scene_path, "PLAY ►", PackedStringArray([chapter.title, chapter.subtitle]))
	return true


func restart_chapter() -> bool:
	return current_chapter != null and start_chapter(current_chapter.id)


# --- Checkpoints ------------------------------------------------------------

func has_checkpoint() -> bool:
	return not (_save.checkpoint as Dictionary).is_empty()


## Chapter id of the saved checkpoint (for a "Continue" button), or &"".
func checkpoint_chapter_id() -> StringName:
	return StringName(_save.checkpoint.get("chapter", ""))


## Id of the saved checkpoint, or &"".
func saved_checkpoint_id() -> StringName:
	return StringName(_save.checkpoint.get("checkpoint", ""))


func save_checkpoint(id: StringName) -> void:
	# Blocked only while the level is still loading behind the tape card (paused). The
	# spawn checkpoint saves as the picture fades in, so "Continue" works right away.
	if current_chapter == null or get_tree().paused:
		return
	_save.checkpoint = {
		"chapter": String(current_chapter.id),
		"checkpoint": String(id),
		"events": Events.snapshot(),
		"flags": _flags.duplicate(),
		"tape_time": _current_tape_time(),
	}
	_write_save()
	checkpoint_saved.emit(id)


## Reloads the level at the last checkpoint. Returns false if there's nothing to load.
func load_checkpoint() -> bool:
	if not has_checkpoint() or _transitioning:
		return false
	var saved: Dictionary = _save.checkpoint
	var chapter := get_chapter(StringName(saved.chapter))
	if chapter == null or not chapter.is_built():
		return false
	current_chapter = chapter
	Events.restore(saved.get("events", {}))
	_flags = (saved.get("flags", {}) as Dictionary).duplicate()
	tape_time_at_load = float(saved.get("tape_time", 0.0))
	_pending_checkpoint = StringName(saved.get("checkpoint", ""))
	_change_level(chapter.scene_path, "PLAY ►", PackedStringArray([chapter.title, chapter.subtitle]))
	return true


# --- Completion ---------------------------------------------------------------

func complete_chapter() -> void:
	if current_chapter == null or _transitioning:
		return
	var finished := current_chapter
	if not is_completed(finished.id):
		(_save.completed as Array).append(String(finished.id))
	_save.checkpoint = {}
	_write_save()
	current_chapter = null
	Events.reset()
	_flags = {}
	tape_time_at_load = 0.0
	chapter_completed.emit(finished)
	_change_level(_hub_path(), "■ STOP", PackedStringArray([finished.title, "END OF TAPE"]))


# --- Flags (small per-chapter facts that must survive a checkpoint load) ------

func set_flag(key: String, value: Variant = true) -> void:
	_flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return _flags.get(key, default)


# --- Save file ----------------------------------------------------------------

func load_save() -> void:
	_save = {"version": SAVE_VERSION, "completed": [], "checkpoint": {}}
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if data is Dictionary:
		_save.completed = data.get("completed", [])
		_save.checkpoint = data.get("checkpoint", {})
	else:
		push_warning("Game: save file unreadable, starting fresh")


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	load_save()


func _write_save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Game: could not write %s (error %d)" % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(_save, "\t"))


# --- Internals ------------------------------------------------------------------

func _change_level(path: String, header: String, lines: PackedStringArray) -> void:
	_transitioning = true
	var tree := get_tree()
	tree.paused = true
	await _transition.cover(header, lines)
	tree.change_scene_to_file(path)
	await tree.scene_changed
	_place_player_at_checkpoint()
	await tree.create_timer(TITLE_CARD_SECONDS, true).timeout
	tree.paused = false
	await _transition.reveal()
	_transitioning = false
	transition_finished.emit()


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
