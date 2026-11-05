extends RefCounted
# Test double for GodotSteam's "Steam" singleton (only what core/achievements.gd calls).

var running: bool = true
var inited: bool = false
var set_ids: Array = []
var stored: int = 0


func _init(is_running: bool = true) -> void:
	running = is_running


func isSteamRunning() -> bool:
	return running


func steamInitEx() -> Dictionary:
	inited = true
	return {"status": 0, "verbal": "OK"}


func setAchievement(id: String) -> bool:
	set_ids.append(id)
	return true


func storeStats() -> bool:
	stored += 1
	return true


func clearAchievement(_id: String) -> bool:
	return true


func run_callbacks() -> void:
	pass
