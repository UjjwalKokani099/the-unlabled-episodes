class_name CCTVMonitor
extends Node3D
## A CCTV monitor showing live, low-res feeds from Marker3D camera spots, cycling every few
## seconds. Only renders while the player is near (cheap). Children: Screen (MeshInstance3D),
## Label (Label3D), Interactable. Using it fires Events `cctv_checked`.
## The feed cameras also see render layer 20 (CCTV_ONLY_LAYER): things only cameras see.
## On mains power (group "mains"): a PowerGrid switches it off and on.
## The screen lights the cabin (studio spec 11): a small shadowless Glow light whose energy
## follows the feed's measured brightness (sampled a moment after every switch), dips black
## for a beat while the switcher changes feeds, and dies with the power.

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
var _glow: OmniLight3D
var _glow_target: float = 0.0
var _blank: float = 0.0
const GLOW_ENERGY := 0.9
## Night CCTV runs at high gain: the picture is brightened on the tube (HDR albedo).
const SCREEN_COLOR := Color(1.7, 2.0, 1.8)


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
	_material.albedo_color = SCREEN_COLOR
	_material.albedo_texture = _viewport.get_texture()
	($Screen as MeshInstance3D).material_override = _material
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.light_color = Color(0.78, 0.92, 0.86)
	_glow.omni_range = 2.6
	_glow.omni_attenuation = 1.6
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	add_child(_glow)
	_glow.global_position = ($Screen as Node3D).global_position + ($Screen as Node3D).global_basis.z * 0.25
	($Interactable as Interactable).interacted.connect(func(_by: Node3D) -> void:
		if not powered:
			get_tree().call_group("hud", "show_message", "No power. The screen is dead.")
			return
		EventBus.fire(&"cctv_checked")
		if use_message != "":
			get_tree().call_group("hud", "show_message", "%s. %s" % [_name(), use_message]))
	_glow_target = 0.5
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
	_material.albedo_color = SCREEN_COLOR if on else Color.BLACK
	($Label as Label3D).visible = on
	if not on:
		_glow_target = 0.0
		_glow.light_energy = 0.0


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_near = player != null and player.global_position.distance_to(global_position) < active_distance
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if (_near and powered) else SubViewport.UPDATE_DISABLED
	_update_glow(delta)
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
	_blank = 0.12  # the switcher blanks between feeds
	if is_inside_tree() and _near and powered:
		_sample_brightness.call_deferred()


## Average brightness of the feed now on screen, read back once per switch (small image).
func _sample_brightness() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not powered:
		return
	var img := _viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(8, 6, Image.INTERPOLATE_BILINEAR)
	var sum := 0.0
	for y in 6:
		for x in 8:
			sum += img.get_pixel(x, y).get_luminance()
	_glow_target = clampf(sum / 48.0 * SCREEN_COLOR.g * 1.4, 0.18, 1.0)


func _update_glow(delta: float) -> void:
	_blank = maxf(_blank - delta, 0.0)
	var screen_on := powered and _blank <= 0.0
	_material.albedo_color = SCREEN_COLOR if screen_on else Color.BLACK
	var target := GLOW_ENERGY * _glow_target if screen_on and _near else 0.0
	_glow.light_energy = move_toward(_glow.light_energy, target, delta * 6.0)
	_glow.visible = _glow.light_energy > 0.005


## Glow light energy (tests).
func glow_energy() -> float:
	return _glow.light_energy


func _update_label() -> void:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	var clock := "22:40:00"
	if camcorder and camcorder.get(&"osd"):
		var t: int = camcorder.osd.time_of_day()
		clock = "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
	($Label as Label3D).text = "%s   %s" % [_name(), clock]


func _name() -> String:
	return names[current] if current < names.size() else "CAM %d" % (current + 1)
