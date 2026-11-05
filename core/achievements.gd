extends Node
## Achievements (studio spec 15): one per tape + a few secret ones, defined in
## data/achievements.json (id = the Steamworks API name). Unlocks are stored in the save
## (SaveManager.data "achievements") and mirrored to a platform backend when one is there:
## with GodotSteam installed (the "Steam" engine singleton) each unlock calls
## Steam.setAchievement(id) + storeStats(), and earlier local unlocks are pushed on start.
## Without it the game runs exactly the same, local only. Nothing else in the game talks to
## Steam: plugging GodotSteam in later needs no code changes here or anywhere else.
##
## Unlock rules (the "unlock" field): chapter:<chapter id> (EventBus.chapter_completed),
## spotted_any / spotted:<prefix>:<count> (EventBus.spotted), caught (EventBus.player_caught).

signal unlocked(id: StringName, display_name: String)

const PATH := "res://data/achievements.json"

var definitions: Array[Dictionary] = []
var _steam: Object


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		for entry: Dictionary in (data as Dictionary).get("achievements", []):
			definitions.append(entry)
	if Engine.has_singleton("Steam"):
		use_backend(Engine.get_singleton("Steam"))
	EventBus.chapter_completed.connect(func(chapter: ChapterData) -> void:
		_check("chapter:" + String(chapter.id)))
	EventBus.spotted.connect(func(_id: StringName) -> void: _check_spots())
	EventBus.player_caught.connect(func() -> void: _check("caught"))


## Plugs in a Steam-like backend (GodotSteam's singleton, or a test double): initialises it
## if it needs it (steamInitEx; Steam not running = stay local), then pushes earlier unlocks.
func use_backend(steam: Object) -> void:
	_steam = steam
	if steam.has_method(&"isSteamRunning") and not bool(steam.call(&"isSteamRunning")):
		_steam = null
	elif steam.has_method(&"steamInitEx"):
		var result: Variant = steam.call(&"steamInitEx")
		if result is Dictionary and int((result as Dictionary).get("status", 0)) != 0:
			push_warning("Achievements: Steam init failed (%s); local only" % (result as Dictionary).get("verbal", "?"))
			_steam = null
	if _steam:
		_sync_to_backend.call_deferred()


func _process(_delta: float) -> void:
	if _steam and _steam.has_method(&"run_callbacks"):
		_steam.call(&"run_callbacks")


## "steam" when GodotSteam is present, else "local".
func backend() -> String:
	return "steam" if _steam else "local"


func is_unlocked(id: StringName) -> bool:
	return String(id) in _list()


func unlocked_ids() -> PackedStringArray:
	return PackedStringArray(_list())


## Unlocks `id` once (no-op if unknown or already unlocked). Returns true if newly unlocked.
func unlock(id: StringName) -> bool:
	var def := _definition(id)
	if def.is_empty() or is_unlocked(id):
		return false
	var list := _list()
	list.append(String(id))
	SaveManager.data["achievements"] = list
	SaveManager.write()
	_push(String(id))
	unlocked.emit(id, String(def.get("name", id)))
	return true


## Clears every unlock (tests; a debug "reset achievements").
func reset() -> void:
	SaveManager.data["achievements"] = []
	if _steam and _steam.has_method(&"clearAchievement"):
		for def in definitions:
			_steam.call(&"clearAchievement", String(def.id))
		_steam.call(&"storeStats")


func _check(rule: String) -> void:
	for def in definitions:
		if String(def.get("unlock", "")) == rule:
			unlock(StringName(def.id))


func _check_spots() -> void:
	for def in definitions:
		var rule := String(def.get("unlock", ""))
		if rule == "spotted_any":
			unlock(StringName(def.id))
		elif rule.begins_with("spotted:"):
			var parts := rule.split(":")
			if parts.size() == 3 and GameManager.spotted_count(parts[1]) >= int(parts[2]):
				unlock(StringName(def.id))


func _push(id: String) -> void:
	if _steam == null:
		return
	_steam.call(&"setAchievement", id)
	_steam.call(&"storeStats")


func _sync_to_backend() -> void:
	for id in _list():
		_push(String(id))


func _definition(id: StringName) -> Dictionary:
	for def in definitions:
		if String(def.get("id", "")) == String(id):
			return def
	return {}


func _list() -> Array:
	return (SaveManager.data.get("achievements", []) as Array).duplicate()
