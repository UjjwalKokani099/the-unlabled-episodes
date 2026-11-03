class_name CCTVMonitor
extends Node3D
## A CCTV monitor showing live, low-res feeds from Marker3D camera spots, cycling every few
## seconds. Only renders while the player is near (cheap). Children: Screen (MeshInstance3D),
## Label (Label3D), Interactable. Using it fires Events `cctv_checked`.
## The feed cameras also see render layer 20 (CCTV_ONLY_LAYER): things only cameras see.
## On mains power (group "mains"): a PowerGrid switches it off and on.

signal camera_changed(index: int)

const CCTV_ONLY_LAYER := 1 << 19

@export var cameras: Array[NodePath] = []
@export var names: PackedStringArray = []
@export var resolution: Vector2i = Vector2i(200, 150)
@export var switch_seconds: float = 4.0
@export var active_distance: float = 10.0
## Message after "CAM n  NAME." when used. Empty = no message (a level script talks).
@export var use_message: String = "Nothing moving."

var current: int = 0
var powered: bool = true
var _viewport: SubViewport
var _camera: Camera3D
var _time: float = 0.0
var _hold: float = 0.0
var _material: StandardMaterial3D
var _near: bool = false


func _ready() -> void:
	add_to_group("mains")
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.cull_mask = PropModel.CCTV_CULL_MASK  # CCTV-only things too, not camera bodies
	_viewport.add_child(_camera)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.85, 1.0, 0.9)
	_material.albedo_texture = _viewport.get_texture()
	($Screen as MeshInstance3D).material_override = _material
	($Interactable as Interactable).interacted.connect(func(_by: Node3D) -> void:
		if not powered:
			get_tree().call_group("hud", "show_message", "No power. The screen is dead.")
			return
		EventBus.fire(&"cctv_checked")
		if use_message != "":
			get_tree().call_group("hud", "show_message", "%s. %s" % [_name(), use_message]))
	_show(0)


## True while the screen shows a picture the player can see.
func is_live() -> bool:
	return powered and _near


## Jump to feed `index` and stay on it for `hold_seconds` before cycling on.
func show_camera(index: int, hold_seconds: float = 0.0) -> void:
	_time = 0.0
	_hold = hold_seconds
	_show(index)


func set_power(on: bool) -> void:
	powered = on
	_material.albedo_color = Color(0.85, 1.0, 0.9) if on else Color.BLACK
	($Label as Label3D).visible = on


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_near = player != null and player.global_position.distance_to(global_position) < active_distance
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if (_near and powered) else SubViewport.UPDATE_DISABLED
	if not powered:
		return
	_time += delta
	if _time >= switch_seconds + _hold:
		_time = 0.0
		_hold = 0.0
		_show((current + 1) % maxi(cameras.size(), 1))
	elif _near and Engine.get_process_frames() % 30 == 0:
		_update_label()


func _show(index: int) -> void:
	current = index
	if cameras.is_empty():
		return
	var spot := get_node(cameras[index]) as Node3D
	_camera.global_transform = spot.global_transform
	_camera.fov = float(spot.get_meta(&"fov", 75.0))  # narrow lens = metadata/fov on the marker
	_update_label()
	camera_changed.emit(index)


func _update_label() -> void:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	var clock := "22:40:00"
	if camcorder and camcorder.get(&"osd"):
		var t: int = camcorder.osd.time_of_day()
		clock = "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
	($Label as Label3D).text = "%s   %s" % [_name(), clock]


func _name() -> String:
	return names[current] if current < names.size() else "CAM %d" % (current + 1)
