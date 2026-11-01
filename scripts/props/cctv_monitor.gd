class_name CCTVMonitor
extends Node3D
## A CCTV monitor showing live, low-res feeds from Marker3D camera spots, cycling every few
## seconds. Only renders while the player is near (cheap). Children: Screen (MeshInstance3D),
## Label (Label3D), Interactable. Using it fires Events `cctv_checked`.

@export var cameras: Array[NodePath] = []
@export var names: PackedStringArray = []
@export var resolution: Vector2i = Vector2i(200, 150)
@export var switch_seconds: float = 4.0
@export var active_distance: float = 10.0

var current: int = 0
var _viewport: SubViewport
var _camera: Camera3D
var _time: float = 0.0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 75.0
	_viewport.add_child(_camera)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 1.0, 0.9)
	mat.albedo_texture = _viewport.get_texture()
	($Screen as MeshInstance3D).material_override = mat
	($Interactable as Interactable).interacted.connect(func(_by: Node3D) -> void:
		Events.fire(&"cctv_checked")
		get_tree().call_group("hud", "show_message", "%s. Nothing moving." % _name()))
	_show(0)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and player.global_position.distance_to(global_position) < active_distance
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if near else SubViewport.UPDATE_DISABLED
	_time += delta
	if _time >= switch_seconds:
		_time = 0.0
		_show((current + 1) % maxi(cameras.size(), 1))


func _show(index: int) -> void:
	current = index
	if cameras.is_empty():
		return
	_camera.global_transform = (get_node(cameras[index]) as Node3D).global_transform
	($Label as Label3D).text = "%s   %s" % [_name(), "22:40:00"]


func _name() -> String:
	return names[current] if current < names.size() else "CAM %d" % (current + 1)
