class_name Dialogue
extends RefCounted
## A branching conversation loaded from a JSON file in res://data/dialogue/. DialogueView (HUD)
## plays it; this class only knows the data and the rules.
##
## File format:
##   {
##     "start": "hello",
##     "nodes": {
##       "hello":  {"speaker": "MRS. IYER", "text": "Arre, new watchman?", "next": "ask"},
##       "ask":    {"speaker": "MRS. IYER", "text": "My parcel?", "choices": [
##                   {"text": "Here it is.", "if": "event:parcel_2c", "next": "thanks",
##                    "event": "parcel_given"},
##                   {"text": "Let me find it.", "next": "find", "set": {"iyer_waiting": true}}]},
##       "fork":   {"branch": [{"if": "flag:promised_gate", "next": "a"}, {"next": "b"}]},
##       "thanks": {"speaker": "MRS. IYER", "text": "Thank you, beta."}
##     }
##   }
## - A node shows `text` by `speaker`, then goes to `next`, offers `choices`, or ends.
## - `branch` nodes show nothing: the first entry whose `if` holds wins.
## - Conditions (`if`, a string or a list that must all hold): "event:<id>" (fired on the
##   Events bus), "flag:<name>" (a dialogue flag is truthy), "!" in front negates.
## - `set` (on a node or a choice) stores dialogue flags; `event` fires an Events id.
##   Flags live in Game flags as "dlg_<name>", so checkpoints keep them.

const FLAG_PREFIX := "dlg_"

static var _cache: Dictionary = {}

var path: String
var start: String
var nodes: Dictionary = {}


## Loads (and caches) a dialogue file. Returns null if it's missing or broken.
static func load_file(file_path: String) -> Dialogue:
	if _cache.has(file_path):
		return _cache[file_path]
	if not FileAccess.file_exists(file_path):
		push_error("Dialogue: no file %s" % file_path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if not (data is Dictionary) or not (data as Dictionary).has("nodes"):
		push_error("Dialogue: %s is not a dialogue file" % file_path)
		return null
	var d := Dialogue.new()
	d.path = file_path
	d.nodes = data.nodes
	d.start = data.get("start", "start")
	_cache[file_path] = d
	return d


## Value of a dialogue flag (set by any conversation).
static func flag(name: String) -> Variant:
	return GameManager.get_flag(FLAG_PREFIX + name, null)


static func set_flag(name: String, value: Variant) -> void:
	GameManager.set_flag(FLAG_PREFIX + name, value)


## True if every condition holds. Accepts "", a string or an array of strings.
static func check(conditions: Variant) -> bool:
	if conditions == null or (conditions is String and conditions == ""):
		return true
	var list: Array = conditions if conditions is Array else [conditions]
	for c: String in list:
		var negate := c.begins_with("!")
		if negate:
			c = c.substr(1)
		var result := false
		if c.begins_with("event:"):
			result = EventBus.has_fired(StringName(c.substr(6)))
		elif c.begins_with("flag:"):
			result = _truthy(flag(c.substr(5)))
		else:
			push_warning("Dialogue: unknown condition '%s'" % c)
		if result == negate:
			return false
	return true


static func _truthy(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool or v is int or v is float:
		return bool(v)
	if v is String or v is StringName:
		return not String(v).is_empty()
	return true


## Applies a node's or choice's effects (`set` flags, `event`).
static func apply(entry: Dictionary) -> void:
	var to_set: Dictionary = entry.get("set", {})
	for key: String in to_set:
		set_flag(key, to_set[key])
	var ev: String = entry.get("event", "")
	if ev != "":
		EventBus.fire(StringName(ev))


## Follows `branch` nodes from `id` to the next node that shows something. "" = the end.
func resolve(id: String) -> String:
	var guard := 0
	while id != "" and nodes.has(id) and nodes[id].has("branch") and guard < 32:
		guard += 1
		var next := ""
		for option: Dictionary in nodes[id].branch:
			if check(option.get("if", "")):
				next = option.get("next", "")
				break
		id = next
	if id != "" and not nodes.has(id):
		push_error("Dialogue %s: no node '%s'" % [path, id])
		return ""
	return id


func node(id: String) -> Dictionary:
	return nodes.get(id, {})


## The choices of a node that are available right now.
func choices(id: String) -> Array:
	var result: Array = []
	for c: Dictionary in node(id).get("choices", []):
		if check(c.get("if", "")):
			result.append(c)
	return result
