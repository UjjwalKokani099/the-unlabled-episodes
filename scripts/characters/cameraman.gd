class_name Cameraman
extends Node3D
## The Cameraman (story bible): thin man, grey sweater, an old shoulder camcorder held over
## his face, its red REC light blinking. He never moves on camera. Scene:
## scenes/characters/cameraman.tscn (RecDot mesh + RecLight children).
##
## - `spot_id` set: he is one of the tape's hidden appearances (a Spottable is added).
## - `vanish_when_unseen`: once the player has really seen him (on screen, no wall in the
##   way) and looks away, or walks up close, he is gone.
## - `cctv_only`: only CCTV cameras see him.
## - Tracking errors grow while the player looks at him (bible: proximity warning).
## Appears only while `active`; set it from a level script.

signal vanished

@export var active: bool = true:
	set(value):
		active = value
		if is_node_ready():
			_refresh()
@export var spot_id: StringName
@export var vanish_when_unseen: bool = false
@export var vanish_distance: float = 3.0
@export var cctv_only: bool = false
## How far away he can still be spotted (a figure on a far balcony needs more).
@export var spot_max_distance: float = 30.0
## REC light always on instead of blinking (the last frame of a tape).
@export var steady_dot: bool = false
## VHS glitch while seen (0 = none).
@export var tracking_noise: float = 0.35

var gone: bool = false
var _seen_time: float = 0.0
var _blink: float = 0.0
var _spot: Spottable

@onready var _dot: MeshInstance3D = $RecDot
@onready var _light: OmniLight3D = $RecLight


func _ready() -> void:
	if cctv_only:
		CCTVOnly.apply_to(self)
		_light.light_energy = 0.0  # it would only light him (CCTV-only lights): the dot glows on its own
	if spot_id != &"":
		_spot = Spottable.new()
		_spot.spot_id = spot_id
		_spot.position = Vector3(0, 1.55, 0)
		_spot.max_distance = spot_max_distance
		add_child(_spot)
	_refresh()


func _refresh() -> void:
	visible = active and not gone
	process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	if _spot:
		_spot.active = visible and not cctv_only


func vanish() -> void:
	if gone:
		return
	gone = true
	_refresh()
	vanished.emit()


func _process(delta: float) -> void:
	_blink += delta
	var on := steady_dot or fmod(_blink, 1.0) < 0.6
	_dot.visible = on
	_light.visible = on
	if cctv_only:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var seen := _is_seen_by(camera)
	var distance := camera.global_position.distance_to(global_position)
	if seen:
		_seen_time += delta
		if tracking_noise > 0.0 and Engine.get_process_frames() % 20 == 0:
			var closeness := clampf(1.0 - distance / 20.0, 0.15, 1.0)
			get_tree().call_group("camcorder", "glitch", tracking_noise * closeness, 0.4)
	if vanish_when_unseen and ((_seen_time > 0.35 and not seen) or distance < vanish_distance):
		get_tree().call_group("camcorder", "glitch", 0.6, 0.35)
		vanish()


func _is_seen_by(camera: Camera3D) -> bool:
	var head := global_position + Vector3(0, 1.5, 0)
	if not camera.is_position_in_frustum(head):
		return false
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, head, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or from.distance_to(hit.position) > from.distance_to(head) - 0.4
