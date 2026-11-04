class_name VHSEffect
extends ColorRect
## Drives assets/shaders/vhs.gdshader: strength from SettingsManager.screen_effects, plus glitch spikes.

var _glitch: float = 0.0
var _glitch_decay: float = 0.0
var _night_vision: bool = false

@onready var _material: ShaderMaterial = material


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_strength()
	SettingsManager.changed.connect(func(key: StringName) -> void:
		if key in [&"screen_effects", &"ps1_mode", &"film_grain", &"chromatic_aberration", &"vignette", &"tape_blur"]:
			_apply_strength())


## Spike distortion to `amount` (0..1), fading out over `duration` seconds.
func glitch(amount: float, duration: float) -> void:
	amount *= SettingsManager.flash_scale()  # Reduce flashing (accessibility)
	if amount >= _glitch:
		_glitch = clampf(amount, 0.0, 1.0)
		_glitch_decay = _glitch / maxf(duration, 0.01)
	_material.set_shader_parameter(&"glitch", _glitch)


## Freeze-frame look on/off (shader judder + tracking band).
func set_paused(paused: bool) -> void:
	_material.set_shader_parameter(&"pause_amount", 1.0 if paused else 0.0)


## Camcorder night vision on/off (shown even when the VHS effect is turned off).
func set_night_vision(on: bool) -> void:
	_night_vision = on
	_material.set_shader_parameter(&"night_vision", 1.0 if on else 0.0)
	_apply_strength()


func get_glitch() -> float:
	return _glitch


func _process(delta: float) -> void:
	if _glitch <= 0.0:
		return
	_glitch = maxf(_glitch - _glitch_decay * delta, 0.0)
	_material.set_shader_parameter(&"glitch", _glitch)


func _apply_strength() -> void:
	_material.set_shader_parameter(&"strength", SettingsManager.screen_effects)
	# PS1 mode: less smear, so the chunky 480-line pixels survive the tape look.
	var bleed := 0.08 if SettingsManager.ps1_mode else 0.35
	_material.set_shader_parameter(&"bleed", bleed if SettingsManager.tape_blur else 0.0)
	var split := 0.9 if SettingsManager.ps1_mode else 1.6
	_material.set_shader_parameter(&"aberration_px", split if SettingsManager.chromatic_aberration else 0.0)
	_material.set_shader_parameter(&"noise_amount", 0.055 if SettingsManager.film_grain else 0.0)
	_material.set_shader_parameter(&"vignette", 0.45 if SettingsManager.vignette else 0.0)
	visible = SettingsManager.screen_effects > 0.0 or _night_vision
