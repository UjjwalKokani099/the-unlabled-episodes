class_name VHSEffect
extends ColorRect
## Drives shaders/vhs.gdshader: strength from Settings.screen_effects, plus glitch spikes.

var _glitch: float = 0.0
var _glitch_decay: float = 0.0

@onready var _material: ShaderMaterial = material


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_strength()
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"screen_effects":
			_apply_strength())


## Spike distortion to `amount` (0..1), fading out over `duration` seconds.
func glitch(amount: float, duration: float) -> void:
	if amount >= _glitch:
		_glitch = clampf(amount, 0.0, 1.0)
		_glitch_decay = _glitch / maxf(duration, 0.01)
	_material.set_shader_parameter(&"glitch", _glitch)


func get_glitch() -> float:
	return _glitch


func _process(delta: float) -> void:
	if _glitch <= 0.0:
		return
	_glitch = maxf(_glitch - _glitch_decay * delta, 0.0)
	_material.set_shader_parameter(&"glitch", _glitch)


func _apply_strength() -> void:
	_material.set_shader_parameter(&"strength", Settings.screen_effects)
	visible = Settings.screen_effects > 0.0
