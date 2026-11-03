class_name CharacterLife
extends Node
## Small procedural life for the generated characters (tools/gen_characters.py puts this as
## the child "Life" of every character root). It never touches Body/Head (NPC head tracking
## owns that) or Body's position (the NPC's bob).
##
## - Breathing: the Chest pivot swells a little, faster after walking.
## - Blinking: EyelidL/EyelidR (closed = scale.y 1) flick shut every few seconds.
## - Walking: HipL/HipR + KneeL/KneeR swing, ShoulderL/ShoulderR + ElbowL/ElbowR counter-
##   swing (unless `swing_arms` is off, e.g. the Cameraman holding his camcorder up).
##   "Walking" = an ancestor NPC's `walking` flag, or any ancestor body moving.
## - Idle: a slow weight shift (hips) and the odd glance down for the old and tired.

@export var swing_arms: bool = true
## Steps per metre walked feel: higher = shorter, quicker steps (old people shuffle).
@export var stride_rate: float = 5.5
## Degrees of leg swing at full stride.
@export var stride_deg: float = 24.0
## Forward lean in degrees (applied to Chest), e.g. an old man's stoop.
@export var stoop_deg: float = 0.0
@export var blink: bool = true

var _t: float = 0.0
var _walk_blend: float = 0.0
var _breath_rate: float = 1.5
var _next_blink: float = 2.0
var _blink_t: float = -1.0
var _owner_body: Node
var _parts := {}
var _rest := {}


func _ready() -> void:
	var root := get_parent()
	for part_name in ["Chest", "HipL", "HipR", "KneeL", "KneeR", "ShoulderL", "ShoulderR", "ElbowL", "ElbowR",
			"EyelidL", "EyelidR", "Pelvis"]:
		var node := root.find_child(part_name, true, false) as Node3D
		if node:
			_parts[part_name] = node
			_rest[part_name] = node.transform
	var node := root.get_parent()
	while node:
		if node is CharacterBody3D or &"walking" in node:
			_owner_body = node
			break
		node = node.get_parent()
	_t = randf() * 10.0
	_next_blink = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	_t += delta
	var walking := _is_walking()
	_walk_blend = move_toward(_walk_blend, 1.0 if walking else 0.0, delta * 3.0)
	_breath_rate = lerpf(_breath_rate, 2.4 if walking else 1.5, delta * 0.3)
	_breathe()
	_walk()
	_blink(delta)


func _is_walking() -> bool:
	if _owner_body == null:
		return false
	if &"walking" in _owner_body and _owner_body.get(&"walking"):
		return true
	if _owner_body is CharacterBody3D:
		var v := (_owner_body as CharacterBody3D).velocity
		return Vector2(v.x, v.z).length() > 0.15
	return false


func _set_rot(part: String, rot: Vector3) -> void:
	if not _parts.has(part):
		return
	var rest: Transform3D = _rest[part]
	(_parts[part] as Node3D).transform = Transform3D(rest.basis * Basis.from_euler(rot), rest.origin)


func _breathe() -> void:
	if not _parts.has("Chest"):
		return
	var chest := _parts["Chest"] as Node3D
	var rest: Transform3D = _rest["Chest"]
	var b := sin(_t * _breath_rate) * 0.5 + 0.5
	var lean := deg_to_rad(stoop_deg) + _walk_blend * deg_to_rad(3.0)
	chest.transform = Transform3D(rest.basis * Basis.from_euler(Vector3(-lean, 0, 0)), rest.origin)
	chest.scale = Vector3(1.0 + b * 0.015, 1.0 + b * 0.01, 1.0 + b * 0.03)


func _walk() -> void:
	var phase := _t * stride_rate
	var s := sin(phase) * _walk_blend
	var swing := deg_to_rad(stride_deg)
	# Idle weight shift: hips sway a degree or two when standing.
	var shift := sin(_t * 0.35) * deg_to_rad(1.5) * (1.0 - _walk_blend)
	_set_rot("Pelvis", Vector3(0, 0, shift))
	_set_rot("HipL", Vector3(s * swing, 0, -shift))
	_set_rot("HipR", Vector3(-s * swing, 0, -shift))
	# Knees bend on the back-swing only.
	_set_rot("KneeL", Vector3(-maxf(0.0, -sin(phase)) * swing * 1.6 * _walk_blend, 0, 0))
	_set_rot("KneeR", Vector3(-maxf(0.0, sin(phase)) * swing * 1.6 * _walk_blend, 0, 0))
	if swing_arms:
		var arm := deg_to_rad(stride_deg * 0.7)
		var idle := sin(_t * 0.5) * deg_to_rad(1.0) * (1.0 - _walk_blend)
		_set_rot("ShoulderL", Vector3(-s * arm + idle, 0, 0))
		_set_rot("ShoulderR", Vector3(s * arm + idle, 0, 0))
		_set_rot("ElbowL", Vector3(deg_to_rad(8.0) + maxf(0.0, s) * arm * 0.6, 0, 0))
		_set_rot("ElbowR", Vector3(deg_to_rad(8.0) + maxf(0.0, -s) * arm * 0.6, 0, 0))


func _blink(delta: float) -> void:
	if not blink or not _parts.has("EyelidL"):
		return
	_next_blink -= delta
	if _next_blink <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_next_blink = randf_range(2.0, 6.0)
	var closed := 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		closed = sin(clampf(_blink_t / 0.16, 0.0, 1.0) * PI)
		if _blink_t > 0.16:
			_blink_t = -1.0
	for lid in ["EyelidL", "EyelidR"]:
		var node := _parts[lid] as Node3D
		node.scale = Vector3(1, maxf(closed, 0.05), 1)
