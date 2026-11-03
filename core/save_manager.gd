extends Node
## Save file storage, registered as the autoload "SaveManager". Knows nothing about chapters:
## GameManager decides WHAT is saved, this decides HOW.
##
## - One slot: user://saves/save_slot.json, a versioned schema ("save_version") with
##   step-by-step migrations (v1 = the old user://save.json, moved over automatically).
## - Corruption-safe writes: JSON goes to <slot>.tmp first, the previous good file is kept as
##   <slot>.bak, then the temp file is renamed into place. Loading falls back to the backup.
## - Tests point `save_path` at their own file so they never touch the player's save.

signal written

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://saves/save_slot.json"
const LEGACY_PATH := "user://save.json"

var save_path: String = DEFAULT_PATH
## The whole save as plain JSON-safe data. Read and change it, then call write().
var data: Dictionary = {}
## Set when the last load had to use the backup (or start fresh after corruption).
var recovered_from_backup: bool = false


func _ready() -> void:
	load_save()


## Fresh, current-version data.
static func defaults() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"completed": [],
		"checkpoint": {},
		"intro_seen": false,
		"spotted": [],
		"memory": [],
		"play_time": 0.0,
		"chapter_times": {},
	}


func load_save() -> void:
	recovered_from_backup = false
	data = defaults()
	var raw: Variant = _read(save_path)
	if raw == null and FileAccess.file_exists(save_path + ".bak"):
		raw = _read(save_path + ".bak")
		recovered_from_backup = raw != null
		if recovered_from_backup:
			push_warning("SaveManager: %s unreadable, restored the backup" % save_path)
	if raw == null and save_path == DEFAULT_PATH and FileAccess.file_exists(LEGACY_PATH):
		raw = _read(LEGACY_PATH)  # pre-v2 location
	if raw is Dictionary:
		var migrated := migrate(raw as Dictionary)
		for key: String in migrated:
			data[key] = migrated[key]


## Upgrades saved data of any older version to SAVE_VERSION, one step at a time.
static func migrate(raw: Dictionary) -> Dictionary:
	var out := raw.duplicate(true)
	var version: int = int(out.get("save_version", out.get("version", 1)))
	if version < 2:  # v1 -> v2: "version" key renamed, play time added
		out.erase("version")
		out["play_time"] = 0.0
		out["chapter_times"] = {}
		version = 2
	out["save_version"] = version
	return out


## Writes `data` safely. Returns false (and keeps the old file) if anything fails.
func write() -> bool:
	var dir := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp := save_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path + ".bak")
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		push_warning("SaveManager: could not move %s into place (error %d)" % [tmp, err])
		return false
	written.emit()
	return true


func exists() -> bool:
	return FileAccess.file_exists(save_path)


## Deletes the slot, its backup and temp file, and resets `data`.
func delete_save() -> void:
	for path in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if save_path == DEFAULT_PATH and FileAccess.file_exists(LEGACY_PATH):
		DirAccess.remove_absolute(LEGACY_PATH)
	data = defaults()


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else null
