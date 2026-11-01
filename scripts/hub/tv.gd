class_name HubTV
extends Node3D
## The hub's CRT. Shows static (hissing, flickering light on the room) or the VCR's blue
## screen with text. Expects children: Screen (MeshInstance3D with tv_screen shader),
## Glow (OmniLight3D), ScreenText (Label3D), Hiss (AudioStreamPlayer3D).

enum Mode { STATIC, BLUE, OFF }

const STATIC_LIGHT := Color(0.75, 0.8, 0.95)
const BLUE_LIGHT := Color(0.2, 0.35, 1.0)

@export var light_energy: float = 0.9

var mode: Mode = Mode.STATIC

@onready var _screen: MeshInstance3D = $Screen
@onready var _glow: OmniLight3D = $Glow
@onready var _text: Label3D = $ScreenText
@onready var _hiss: AudioStreamPlayer3D = $Hiss


func _ready() -> void:
	_hiss.finished.connect(_on_hiss_finished)
	set_mode(Mode.STATIC)


func set_mode(new_mode: Mode, text: String = "") -> void:
	mode = new_mode
	(_screen.get_active_material(0) as ShaderMaterial).set_shader_parameter(&"mode", int(new_mode))
	_text.text = text
	_text.visible = new_mode == Mode.BLUE and text != ""
	_glow.visible = new_mode != Mode.OFF
	_glow.light_color = BLUE_LIGHT if new_mode == Mode.BLUE else STATIC_LIGHT
	_glow.light_energy = light_energy
	if new_mode == Mode.STATIC:
		if not _hiss.playing:
			_hiss.play()
	else:
		_hiss.stop()


func _process(_delta: float) -> void:
	if mode == Mode.STATIC:
		_glow.light_energy = light_energy * randf_range(0.7, 1.0)


func _on_hiss_finished() -> void:
	if mode == Mode.STATIC:
		_hiss.play()
