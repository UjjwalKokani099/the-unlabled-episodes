class_name Camcorder
extends Node
## Camcorder overlay root (ui/hud/camcorder.tscn): OSD + VHS effect.
## Anything can glitch the picture: get_tree().call_group("camcorder", "glitch", 0.8, 0.5)
## Tape cut (the camcorder was stopped and started later):
##     get_tree().call_group("camcorder", "tape_cut", "03:11:20")
## The Spot key ("spot") is the camcorder's PAUSE button: looking at a Spottable (the
## Cameraman's hidden appearances) and pressing it freezes the frame and counts it.
## Night vision ("night_vision", N): green amplified picture + an infrared fill light on the
## camera; drains the battery (OSD icon). Battery pickups (Events `battery`) recharge it.
## PS1 mode (SettingsManager.ps1_mode): a pixelate/dither pass under the OSD (assets/shaders/ps1_post).

signal cut_finished
signal spotted(spot_id: StringName)

const STATIC_SHADER := preload("res://assets/shaders/static_bg.gdshader")
const STATIC_SOUND := preload("res://assets/audio/sfx/tv_static.wav")
const CLICK_SOUND := preload("res://assets/audio/sfx/vcr_click.wav")
const PAUSE_SECONDS := 1.6
const PS1_SHADER := preload("res://assets/shaders/ps1_post.gdshader")
## Full battery lasts this many seconds of night vision.
const NV_BATTERY_SECONDS := 240.0
const BATTERY_PICKUP := 0.5

var is_cutting: bool = false
var is_frozen: bool = false
var night_vision: bool = false

var _cut_layer: CanvasLayer
var _black: ColorRect
var _static: ColorRect
var _sound: AudioStreamPlayer
var _retro: ColorRect
var _ir_light: OmniLight3D

@onready var osd: CamcorderOSD = $OSDLayer/OSD
@onready var vhs: VHSEffect = $VHSLayer/VHS


func _ready() -> void:
	add_to_group("camcorder")
	process_mode = Node.PROCESS_MODE_ALWAYS
	osd.process_mode = Node.PROCESS_MODE_PAUSABLE
	_cut_layer = CanvasLayer.new()
	_cut_layer.layer = 1  # under the OSD and the VHS effect, so both stay on top
	add_child(_cut_layer)
	# Drawn first in the layer: the PS1 pass sits under the tape-cut rects.
	_retro = _full_rect(Color.WHITE)
	var retro_mat := ShaderMaterial.new()
	retro_mat.shader = PS1_SHADER
	_retro.material = retro_mat
	_retro.visible = SettingsManager.ps1_mode
	SettingsManager.changed.connect(func(key: StringName) -> void:
		if key == &"ps1_mode":
			_retro.visible = SettingsManager.ps1_mode)
	EventBus.fired.connect(func(id: StringName) -> void:
		if id == &"battery" and not EventBus.replaying:
			osd.battery_level += BATTERY_PICKUP)
	_black = _full_rect(Color.BLACK)
	_static = _full_rect(Color.WHITE)
	var mat := ShaderMaterial.new()
	mat.shader = STATIC_SHADER
	mat.set_shader_parameter(&"strength", 0.9)
	_static.material = mat
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	add_child(_sound)


func glitch(amount: float, duration: float = 0.5) -> void:
	vhs.glitch(amount, duration)


## Static, a moment of black, then the picture comes back with the clock moved on to
## `to_time` ("hh:mm:ss"). Await `cut_finished` (or this call) to continue.
func tape_cut(to_time: String, black_seconds: float = 1.2) -> void:
	is_cutting = true
	_play(STATIC_SOUND, -6.0)
	vhs.glitch(1.0, 0.6)
	_show_static_rect()
	await get_tree().create_timer(0.45).timeout
	_static.visible = false
	_black.visible = true
	_sound.stop()
	osd.jump_to_time(to_time)
	await get_tree().create_timer(black_seconds).timeout
	_play(CLICK_SOUND, -4.0)
	_black.visible = false
	vhs.glitch(0.7, 0.8)
	is_cutting = false
	cut_finished.emit()


## Full-screen static (end of a tape). Stays until hide_static().
func show_static(with_sound: bool = true) -> void:
	_show_static_rect()
	if with_sound:
		_play(STATIC_SOUND, -4.0)


## Static is dimmed with Reduce flashing on (accessibility).
func _show_static_rect() -> void:
	var tone := 0.45 if SettingsManager.reduce_flashing else 1.0
	_static.modulate = Color(tone, tone, tone)
	_static.visible = true


func hide_static() -> void:
	_static.visible = false
	_sound.stop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"spot"):
		try_spot()
	elif event.is_action_pressed(&"night_vision"):
		set_night_vision(not night_vision)


## Night vision on/off. Can't switch on with a dead battery.
func set_night_vision(on: bool) -> void:
	if on and osd.battery_level <= 0.0:
		get_tree().call_group("hud", "show_message", "Battery dead.")
		on = false
	if on == night_vision:
		return
	night_vision = on
	vhs.set_night_vision(on)
	osd.get_node("Mode").text = "SP   NIGHT" if on else "SP"
	_play(CLICK_SOUND, -8.0)
	if on:
		_attach_ir_light()
	elif is_instance_valid(_ir_light):
		_ir_light.queue_free()


func _process(delta: float) -> void:
	if not night_vision or get_tree().paused:
		return
	if not is_instance_valid(_ir_light):
		_attach_ir_light()  # the camera changed (checkpoint reload)
	osd.battery_level -= delta / NV_BATTERY_SECONDS
	if osd.battery_level <= 0.0:
		set_night_vision(false)
		get_tree().call_group("hud", "show_message", "Battery dead.")


## An invisible infrared lamp on the camcorder: lights what the night vision amplifies.
func _attach_ir_light() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_ir_light = OmniLight3D.new()
	_ir_light.light_energy = 0.5
	_ir_light.omni_range = 7.0
	_ir_light.omni_attenuation = 2.2  # bright up close, black a few metres out
	_ir_light.light_specular = 0.0
	_ir_light.light_volumetric_fog_energy = 0.0
	camera.add_child(_ir_light)


## Looks for a Spottable near the centre of the view. Freezes the frame when it finds
## one the player hasn't spotted before. Returns its id, or &"".
func try_spot() -> StringName:
	if is_frozen or is_cutting or get_tree().paused:
		return &""
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.can_act():
		return &""
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return &""
	var best: Spottable = null
	var best_angle := 1e9
	for node in get_tree().get_nodes_in_group("spottable"):
		var spot := node as Spottable
		var angle := spot.view_angle_from(camera)
		if angle >= 0.0 and angle < best_angle:
			best = spot
			best_angle = angle
	if best == null:
		_play(CLICK_SOUND, -12.0)
		return &""
	_freeze(best)
	return best.spot_id


func _freeze(spot: Spottable) -> void:
	var is_new := GameManager.mark_spotted(spot.spot_id)
	spot.on_spotted()
	spotted.emit(spot.spot_id)
	is_frozen = true
	_play(CLICK_SOUND, -2.0)
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	osd.paused_display = true
	vhs.set_paused(true)
	await tree.create_timer(PAUSE_SECONDS, true).timeout
	vhs.set_paused(false)
	osd.paused_display = false
	tree.paused = was_paused
	is_frozen = false
	_play(CLICK_SOUND, -6.0)
	var total := GameManager.spotted_count()
	var text := "Spotted him. (%d found)" % total if is_new else "Already spotted here."
	tree.call_group("hud", "show_message", text, 3.0)


func _play(stream: AudioStream, volume_db: float) -> void:
	_sound.stream = stream
	_sound.volume_db = volume_db
	_sound.play()


func _full_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	_cut_layer.add_child(rect)
	return rect
