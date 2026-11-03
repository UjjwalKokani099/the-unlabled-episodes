class_name MenuBackdrop
extends Node3D
## Main-menu scene: Nikhil's dim room at night (tube light off). The menu itself is shown
## on the CRT (show_on_tv), the camera drifts in front of it, the TV's glow flickers, and a
## red REC dot blinks in the dark corner. The main menu moves the camera between framings
## (IDLE, CLOSE for settings/tapes, DIVE into the glass when a tape starts).

enum Framing { IDLE, CLOSE, DIVE }

## Must match `curvature` in shaders/crt_screen.gdshader.
const CURVATURE := 0.12
const CRT_SHADER := preload("res://shaders/crt_screen.gdshader")
const SCREEN_TARGET := Vector3(3.15, 0.8, 3.565)
## Camera spots per framing: [position, look-at].
const SPOTS := {
	Framing.IDLE: [Vector3(2.97, 0.93, 2.9), Vector3(3.11, 0.77, 3.56)],
	Framing.CLOSE: [Vector3(3.15, 0.81, 3.08), SCREEN_TARGET],
	Framing.DIVE: [Vector3(3.15, 0.8, 3.42), SCREEN_TARGET],
}

var framing: Framing = Framing.IDLE
var _time: float = 0.0
var _base: Transform3D
var _tween: Tween
var _glow_energy: float = 0.8
var _stutter: float = 0.0
var _next_stutter: float = 5.0
var _screen_size: Vector2 = Vector2(0.44, 0.33)

@onready var _camera: Camera3D = $Camera3D
@onready var _rec: Node3D = $RecDot
@onready var _tv: HubTV = $Room/TV
@onready var _screen: MeshInstance3D = $Room/TV/Screen
@onready var _glow: OmniLight3D = $Room/TV/Glow


func _ready() -> void:
	var room := $Room
	(room.get_node("TubeLight") as TubeLight).on = false
	(room.get_node("DeskLamp") as Light3D).visible = false  # late night: only the TV is on
	(room.get_node("Van") as Node3D).visible = false
	(room.get_node("DeliveryBag") as Node3D).visible = false
	# The lane's street lamp leaves a hot specular spot on the wall behind the TV when
	# the camera leans in; keep its light, drop the highlight.
	(room.get_node("SodiumLight") as Light3D).light_specular = 0.0
	_tv.set_mode(HubTV.Mode.BLUE)  # glow on, no static hiss
	_glow_energy = _glow.light_energy * 0.45  # a dim room: the TV is the only light
	_glow.light_volumetric_fog_energy = 0.0  # the camera leans in right past this light
	var quad := _screen.mesh as QuadMesh
	if quad:
		_screen_size = quad.size
	_base = _spot_transform(Framing.IDLE)
	_camera.transform = _base


## Puts a 2D picture (the menu's SubViewport texture) on the CRT glass.
func show_on_tv(texture: Texture2D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = CRT_SHADER
	mat.set_shader_parameter(&"screen_tex", texture)
	mat.set_shader_parameter(&"curvature", CURVATURE)
	_screen.material_override = mat


## Moves the camera to a framing. Returns the tween (await .finished for the DIVE).
func frame(target: Framing, seconds: float = 0.9) -> Tween:
	framing = target
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_base", _spot_transform(target), seconds)
	return _tween


## Where a screen position (pixels in this scene's viewport) lands on the TV picture, as
## 0..1 UV of the menu texture (through the glass curvature). (-1, -1) = off the screen.
func screen_uv_at(viewport_position: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(viewport_position)
	var dir := _camera.project_ray_normal(viewport_position)
	var plane := Plane(_screen.global_transform.basis.z.normalized(), _screen.global_position)
	var hit: Variant = plane.intersects_ray(origin, dir)
	if hit == null:
		return Vector2(-1, -1)
	var local: Vector3 = _screen.global_transform.affine_inverse() * (hit as Vector3)
	var uv := Vector2(local.x / _screen_size.x + 0.5, 0.5 - local.y / _screen_size.y)
	# Same barrel distortion as the shader: the picture pixel shown at this spot.
	var c := uv - Vector2(0.5, 0.5)
	c *= 1.0 + CURVATURE * c.dot(c)
	uv = c + Vector2(0.5, 0.5)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv


func _process(delta: float) -> void:
	_time += delta
	# Slow handheld drift (less when leaning in to read).
	var amount := 1.0 if framing == Framing.IDLE else 0.35
	var sway := Basis.from_euler(Vector3(sin(_time * 0.13) * 0.010, sin(_time * 0.09) * 0.016, sin(_time * 0.05) * 0.004) * amount)
	_camera.transform = Transform3D(_base.basis * sway, _base.origin + Vector3(sin(_time * 0.07) * 0.02 * amount, 0, 0))
	_rec.visible = fmod(_time, 1.2) < 0.7
	# CRT glow: a constant shimmer plus the odd brown-out stutter.
	_next_stutter -= delta
	if _next_stutter <= 0.0:
		_next_stutter = randf_range(4.0, 11.0)
		_stutter = randf_range(0.25, 0.6)
	_stutter = maxf(_stutter - delta, 0.0)
	var dip := 0.45 if _stutter > 0.0 and fmod(_stutter, 0.12) < 0.06 else 1.0
	_glow.light_energy = _glow_energy * (0.92 + 0.08 * sin(_time * 31.0) * sin(_time * 7.3)) * dip


func _spot_transform(target: Framing) -> Transform3D:
	var spot: Array = SPOTS[target]
	return Transform3D.IDENTITY.translated(spot[0]).looking_at(spot[1], Vector3.UP)
