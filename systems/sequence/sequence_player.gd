class_name SequencePlayer
extends Node
## Scripted events as data (studio spec 5 + 9): every JSON file in `sequences` is one sequence
## = a trigger + steps. Reusable across chapters; levels just list their files. Node paths in
## steps are relative to `root` (the level). Format (see data/sequences/README.md):
##
##   {"id": "intercom", "trigger": {"event": "intercom_answered"}, "once": true,
##    "cutscene": false, "steps": [
##      {"do": "sound", "node": "Story/IntercomBreath"},
##      {"do": "say", "speaker": "RAGHU", "text": "Hello? Hello, 4B?", "seconds": 3.0},
##      {"do": "wait", "seconds": 3.4}, ...]}
##
## Triggers: {"event": id} | {"zone": path (TriggerZone/Area3D)} | {"interact": path
## (Interactable)} | {"time": seconds after the level starts} | {"objective": id (completed)}.
## Steps (`do`): say, think, message, wait, sound (node + optional "stop"), play (file),
## light (energy, seconds), flicker (seconds), door (lock|unlock|open|close|slam), show, hide,
## spawn (scene, at), walk (npc, to | marker, wait), face, set (property, value), call (method,
## args), fire (event), dialogue (file, start), glitch, shake, tension (value, source),
## silence (seconds), objective (complete id), checkpoint (id), look (at path, seconds),
## camera (shot path, seconds, blend, fov), letterbox (on), animation (node, name, wait),
## input (on), if (cond, then, else), parallel (steps).
##
## A running sequence holds saving (never mid-cutscene); `once` sequences remember they ran
## through the EventBus ("seq_<id>"), so checkpoints keep that. Cutscenes ("cutscene": true)
## take the player's input, show the hold-to-skip ring (hold E / A for 1.5 s) and, when
## skipped, finish instantly but still apply every effect (events, doors, positions).

signal started(id: String)
signal finished(id: String)

const SKIP_HOLD := 1.5
const BLEND := 0.5

## Sequence files (res://data/sequences/...json).
@export var sequences: Array[String] = []
## Node the step paths are relative to ("" = the parent).
@export var root: NodePath
## Tests: < 1 speeds every wait and blend up.
@export var time_scale: float = 1.0

var running: Dictionary = {}       # id -> true
var _data: Dictionary = {}         # id -> sequence dict
var _skipping: Dictionary = {}     # id -> true once skip was held
var _skip_held: float = 0.0
var _cutscene_id: String = ""
var _ui: CutsceneOverlay
var _level_time: float = 0.0
var _timed: Array = []             # [seconds, id]


func _ready() -> void:
	_ui = CutsceneOverlay.new()
	add_child(_ui)
	for path in sequences:
		load_sequence(path)
	EventBus.fired.connect(_on_event)
	ObjectiveManager.completed.connect(func(o: ObjectiveData) -> void: _on_trigger("objective", String(o.id)))
	_hook_nodes.call_deferred()


## Adds one sequence file (also usable at runtime / in tests).
func load_sequence(path: String) -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data as Dictionary).has("id"):
		push_error("SequencePlayer: %s is not a sequence" % path)
		return ""
	_data[String(data.id)] = data
	var trig: Dictionary = (data as Dictionary).get("trigger", {})
	if trig.has("time"):
		_timed.append([float(trig.time), String(data.id)])
	return String(data.id)


## Problems in a sequence (unknown step kinds, missing nodes): [] = fine. Tests run it.
func validate(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var seq: Dictionary = _data.get(id, {})
	if seq.is_empty():
		out.append("no sequence %s" % id)
		return out
	_validate_steps(seq.get("steps", []), out)
	return out


func is_running(id: String = "") -> bool:
	return running.has(id) if id != "" else not running.is_empty()


## Runs a sequence now (whatever its trigger). Await it.
func play(id: String) -> void:
	var seq: Dictionary = _data.get(id, {})
	if seq.is_empty() or running.has(id):
		return
	if bool(seq.get("once", true)):
		if EventBus.has_fired(StringName("seq_" + id)):
			return
		EventBus.fire(StringName("seq_" + id))
	running[id] = true
	GameManager.block_saving("sequence:" + id)
	started.emit(id)
	var cutscene := bool(seq.get("cutscene", false))
	if cutscene:
		_cutscene_id = id
		_set_player_input(false)
		_ui.show_skip(true)
	await _run(seq.get("steps", []), id)
	if cutscene:
		_ui.show_skip(false)
		_ui.letterbox(false, 0.0 if _skipping.has(id) else BLEND * time_scale)
		await _restore_camera(id)
		_set_player_input(true)
		_cutscene_id = ""
	_skipping.erase(id)
	running.erase(id)
	GameManager.unblock_saving("sequence:" + id)
	finished.emit(id)


## Skip the running cutscene (what holding E for 1.5 s does).
func skip() -> void:
	if _cutscene_id != "":
		_skipping[_cutscene_id] = true


func _process(delta: float) -> void:
	_level_time += delta
	for entry: Array in _timed.duplicate():
		if _level_time >= float(entry[0]) * time_scale:
			_timed.erase(entry)
			_on_trigger("time", String(entry[1]))
	if _cutscene_id != "" and not _skipping.has(_cutscene_id):
		if Input.is_action_pressed(&"interact"):
			_skip_held += delta
			if _skip_held >= SKIP_HOLD:
				skip()
		else:
			_skip_held = 0.0
		_ui.set_skip_progress(_skip_held / SKIP_HOLD)
	else:
		_skip_held = 0.0


# --- triggers ---------------------------------------------------------------------------

func _on_event(id: StringName) -> void:
	if EventBus.replaying:
		return
	_on_trigger("event", String(id))


func _on_trigger(kind: String, value: String) -> void:
	for id: String in _data:
		var trig: Dictionary = _data[id].get("trigger", {})
		if kind == "time" and id == value and trig.has("time"):
			play(id)
		elif trig.has(kind) and kind != "time" and String(trig[kind]) == value:
			play(id)


func _hook_nodes() -> void:
	for id: String in _data:
		var trig: Dictionary = _data[id].get("trigger", {})
		if trig.has("zone"):
			var zone := _node(String(trig.zone)) as Area3D
			if zone:
				zone.body_entered.connect(func(body: Node3D) -> void:
					if body is Player:
						play(id))
		if trig.has("interact"):
			var it := _node(String(trig.interact)) as Interactable
			if it:
				it.interacted.connect(func(_by: Node3D) -> void: play(id))


# --- steps --------------------------------------------------------------------------------

func _run(steps: Array, id: String) -> void:
	for step: Dictionary in steps:
		if not is_inside_tree():
			return
		await _step(step, id)


func _step(s: Dictionary, id: String) -> void:
	var skipping := _skipping.has(id)
	match String(s.get("do", "")):
		"say":
			if not skipping:
				get_tree().call_group("subtitles", "say", String(s.get("speaker", "")), String(s.text),
					float(s.get("seconds", 3.0)), String(s.get("voice", "")))
		"think":
			if not skipping:
				get_tree().call_group("subtitles", "think", String(s.text), float(s.get("seconds", 3.0)))
		"message":
			if not skipping:
				get_tree().call_group("hud", "show_message", String(s.text), float(s.get("seconds", 2.5)))
		"wait":
			await _wait(float(s.get("seconds", 1.0)), id)
		"sound":
			var player := _node(String(s.node))
			if player and player.has_method(&"play") and not skipping:
				if bool(s.get("stop", false)):
					player.call(&"stop")
				else:
					player.call(&"play")
			elif player and bool(s.get("stop", false)):
				player.call(&"stop")
		"play":
			if not skipping:
				var stream := load(String(s.file)) as AudioStream
				if stream:
					if s.has("at"):
						AudioManager.play_at(stream, _vec(s.at), float(s.get("volume_db", 0.0)))
					else:
						AudioManager.play_sfx(stream, float(s.get("volume_db", 0.0)))
		"light":
			var light := _node(String(s.node)) as Light3D
			if light:
				var secs := 0.0 if skipping else float(s.get("seconds", 0.0)) * time_scale
				if secs <= 0.0:
					light.light_energy = float(s.energy)
				else:
					create_tween().tween_property(light, "light_energy", float(s.energy), secs)
		"flicker":
			var target := _node(String(s.node)) as Light3D
			if target and not skipping:
				_flicker(target, float(s.get("seconds", 1.0)) * time_scale)
		"door":
			var door := _node(String(s.node)) as Door
			if door:
				match String(s.get("action", "lock")):
					"lock":
						door.lock()
					"unlock":
						door.unlock()
					"open":
						door.open_away_from(door.global_position + door.global_basis.z)
					"close":
						door.close()
					"slam":
						door.slam(bool(s.get("lock", false)))
		"show", "hide":
			var n := _node(String(s.node)) as Node3D
			if n:
				n.visible = s.do == "show"
		"spawn":
			var scene := load(String(s.scene)) as PackedScene
			var parent := _node(String(s.get("parent", ".")))
			if scene and parent:
				var inst := scene.instantiate()
				parent.add_child(inst)
				if inst is Node3D and s.has("at"):
					(inst as Node3D).global_position = _vec(s.at)
				if s.has("name"):
					inst.name = String(s.name)
		"walk":
			var npc := _node(String(s.npc))
			var to := _target_pos(s)
			if npc and npc.has_method(&"walk_to"):
				if skipping:
					(npc as Node3D).global_position = to
				else:
					npc.call(&"walk_to", to)
					if bool(s.get("wait", false)) and npc.has_signal(&"arrived"):
						await npc.arrived
		"face":
			var who := _node(String(s.npc))
			if who and who.has_method(&"face"):
				who.call(&"face", _target_pos(s))
		"set":
			var obj := _node(String(s.node))
			if obj:
				obj.set(StringName(s.property), s.value)
		"call":
			var callee := _node(String(s.node))
			if callee and callee.has_method(StringName(s.method)):
				var result: Variant = callee.callv(StringName(s.method), s.get("args", []))
				if bool(s.get("wait", false)) and result is Signal:
					await result
		"fire":
			EventBus.fire(StringName(s.event))
		"dialogue":
			var view := get_tree().get_first_node_in_group("hud")
			var dv := view.get_node_or_null("DialogueView") if view else null
			if dv:
				dv.call(&"play", String(s.file), String(s.get("start", "")))
				if bool(s.get("wait", true)) and dv.get(&"is_open"):
					await dv.finished
		"glitch":
			if not skipping:
				get_tree().call_group("camcorder", "glitch", float(s.get("amount", 0.5)), float(s.get("seconds", 0.5)))
		"shake":
			if not skipping:
				get_tree().call_group("camera_shake", "add_trauma", float(s.get("amount", 0.3)))
		"tension":
			AudioManager.set_tension(float(s.value), StringName(s.get("source", "sequence")))
		"silence":
			if not skipping:
				AudioManager.hold_silence(float(s.get("seconds", 3.0)), float(s.get("fade_out", 1.0)), float(s.get("fade_in", 2.0)))
		"objective":
			ObjectiveManager.complete(StringName(s.complete))
		"checkpoint":
			GameManager.unblock_saving("sequence:" + id)
			GameManager.save_checkpoint.call_deferred(StringName(s.get("id", "start")))
		"look":
			await _look(s, id)
		"camera":
			await _camera(s, id)
		"letterbox":
			_ui.letterbox(bool(s.get("on", true)), 0.0 if skipping else BLEND * time_scale)
		"animation":
			var ap := _node(String(s.node)) as AnimationPlayer
			if ap:
				ap.play(StringName(s.name))
				if skipping:
					ap.advance(ap.current_animation_length)
				elif bool(s.get("wait", true)):
					await ap.animation_finished
		"input":
			_set_player_input(bool(s.get("on", true)))
		"if":
			var branch: Array = s.get("then", []) if Dialogue.check(s.get("cond", "")) else s.get("else", [])
			await _run(branch, id)
		"parallel":
			var pending := (s.get("steps", []) as Array).size()
			var done := [0]
			for sub: Dictionary in s.get("steps", []):
				(func() -> void:
					await _step(sub, id)
					done[0] += 1).call()
			while done[0] < pending and is_inside_tree():
				await get_tree().process_frame
		_:
			push_warning("SequencePlayer: unknown step '%s' in %s" % [s.get("do", ""), id])


func _wait(seconds: float, id: String) -> void:
	var left := seconds * time_scale
	while left > 0.0 and not _skipping.has(id) and is_inside_tree():
		await get_tree().process_frame
		if not get_tree().paused:
			left -= get_process_delta_time()


func _flicker(light: Light3D, seconds: float) -> void:
	await LightFlicker.run(light, seconds)


# --- camera ------------------------------------------------------------------------------

var _cam: Camera3D
var _player_cam: Camera3D


## First-person "look": the player's own view turns toward a node over `seconds` (eased),
## holds `hold` seconds, then control comes back. Nothing snaps.
func _look(s: Dictionary, id: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var target := _node(String(s.at)) as Node3D
	if player == null or target == null:
		return
	var aim := target.global_position + (Vector3(0, float(s.get("height", 0.0)), 0))
	var to := player.camera.global_position.direction_to(aim)
	var yaw := atan2(-to.x, -to.z)
	var pitch := rad_to_deg(asin(clampf(to.y, -1.0, 1.0)))
	var was_enabled := player.input_enabled
	player.input_enabled = false
	var secs := float(s.get("seconds", BLEND)) * time_scale
	if _skipping.has(id):
		secs = 0.0
	var start_yaw := player.rotation.y
	var start_pitch: float = player.get(&"_pitch")
	var delta_yaw := wrapf(yaw - start_yaw, -PI, PI)
	var t := 0.0
	while t < secs and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := ease(clampf(t / secs, 0.0, 1.0), -2.0)
		player.rotation.y = start_yaw + delta_yaw * k
		player.set(&"_pitch", lerpf(start_pitch, pitch, k))
		player.head.rotation.x = deg_to_rad(player.get(&"_pitch"))
	player.rotation.y = start_yaw + delta_yaw
	player.set(&"_pitch", pitch)
	player.head.rotation.x = deg_to_rad(pitch)
	await _wait(float(s.get("hold", 0.0)), id)
	player.input_enabled = was_enabled if _cutscene_id == "" else false


## Cinematic shot: a camera blends from the player's eye to `shot` (a Node3D's transform)
## over `blend` seconds, holds `seconds`, and the sequence's end blends back (0.5 s).
func _camera(s: Dictionary, id: String) -> void:
	var shot := _node(String(s.shot)) as Node3D
	var player := get_tree().get_first_node_in_group("player") as Player
	if shot == null or player == null:
		return
	if _cam == null:
		_player_cam = player.camera
		_cam = Camera3D.new()
		_cam.name = "CutsceneCamera"
		_cam.fov = _player_cam.fov
		_cam.cull_mask = _player_cam.cull_mask
		get_tree().current_scene.add_child(_cam)
		_cam.global_transform = _player_cam.global_transform
		_cam.current = true
	var blend := 0.0 if _skipping.has(id) else float(s.get("blend", BLEND)) * time_scale
	var fov := float(s.get("fov", _cam.fov))
	if blend <= 0.0:
		_cam.global_transform = shot.global_transform
		_cam.fov = fov
	else:
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_cam, "global_transform", shot.global_transform, blend)
		tw.tween_property(_cam, "fov", fov, blend)
		await tw.finished
	await _wait(float(s.get("seconds", 2.0)), id)


func _restore_camera(id: String) -> void:
	if _cam == null:
		return
	if not _skipping.has(id) and is_instance_valid(_player_cam):
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_cam, "global_transform", _player_cam.global_transform, BLEND * time_scale)
		tw.tween_property(_cam, "fov", _player_cam.fov, BLEND * time_scale)
		await tw.finished
	if is_instance_valid(_player_cam):
		_player_cam.current = true
	_cam.queue_free()
	_cam = null


# --- helpers -------------------------------------------------------------------------------

func _node(path: String) -> Node:
	var base := get_node_or_null(root) if root != NodePath("") else get_parent()
	if base == null:
		return null
	return base if path == "." else base.get_node_or_null(NodePath(path))


func _vec(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _target_pos(s: Dictionary) -> Vector3:
	if s.has("marker"):
		var m := _node(String(s.marker)) as Node3D
		if m:
			return m.global_position
	return _vec(s.get("to", [0, 0, 0]))


func _set_player_input(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_enabled = on


const STEP_KINDS := ["say", "think", "message", "wait", "sound", "play", "light", "flicker", "door", "show",
	"hide", "spawn", "walk", "face", "set", "call", "fire", "dialogue", "glitch", "shake", "tension", "silence",
	"objective", "checkpoint", "look", "camera", "letterbox", "animation", "input", "if", "parallel"]


func _validate_steps(steps: Array, out: PackedStringArray) -> void:
	for s: Dictionary in steps:
		var kind := String(s.get("do", ""))
		if kind not in STEP_KINDS:
			out.append("unknown step '%s'" % kind)
		for key in ["node", "npc", "at", "shot", "marker"]:
			if s.has(key) and _node(String(s[key])) == null:
				out.append("%s: no node %s" % [kind, s[key]])
		for key in ["file", "scene"]:
			if s.has(key) and not ResourceLoader.exists(String(s[key])) and not FileAccess.file_exists(String(s[key])):
				out.append("%s: missing %s" % [kind, s[key]])
		if kind == "if":
			_validate_steps(s.get("then", []), out)
			_validate_steps(s.get("else", []), out)
		if kind == "parallel":
			_validate_steps(s.get("steps", []), out)
