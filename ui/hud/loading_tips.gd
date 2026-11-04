class_name LoadingTips
extends RefCounted
## Random in-world tips for the loading card, from data/loading_tips.json. A tip whose
## "where" is set only shows while loading a scene whose path contains it; "{action}"
## becomes that action's current key. Never the same tip twice in a row.

const PATH := "res://data/loading_tips.json"

static var _tips: Array = []
static var _last: String = ""


## A tip for loading `scene_path` ("" if the file has none that fit).
static func pick(scene_path: String) -> String:
	if _tips.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			_tips = (data as Dictionary).get("tips", [])
	var fitting: Array[String] = []
	for tip: Dictionary in _tips:
		var where: String = tip.get("where", "")
		if where == "" or where in scene_path:
			fitting.append(tip.text)
	if fitting.size() > 1:
		fitting.erase(_last)
	if fitting.is_empty():
		return ""
	_last = fitting.pick_random()
	return fill_keys(_last)


## "{spot}" -> "Q" (the player's current binding).
static func fill_keys(text: String) -> String:
	var out := text
	var start := out.find("{")
	while start >= 0:
		var end := out.find("}", start)
		if end < 0:
			break
		var action := out.substr(start + 1, end - start - 1)
		var key := SettingsManager.key_name(StringName(action)) if InputMap.has_action(action) else action
		out = out.substr(0, start) + "[" + key + "]" + out.substr(end + 1)
		start = out.find("{", start + 1)
	return out
