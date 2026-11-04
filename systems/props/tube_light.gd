class_name TubeLight
extends Node3D
## Fluorescent tube-light fixture (the standard Indian corridor/stairwell light).
## Optional flicker: occasional dropouts and a stuttering start, like an old choke.
## Expects children: Tube (MeshInstance3D, emissive), Light (OmniLight3D); optional Hum
## (AudioStreamPlayer3D): the choke's buzz, only while lit (cuts out in the flicker). Every
## drop-out ticks (LightFlicker.SOUND) in sync with the light.

## Start switched on.
@export var on: bool = true:
	set(value):
		on = value
		if is_node_ready():
			_apply(1.0 if on else 0.0)
## 0 = steady. 1 = very unreliable.
@export_range(0.0, 1.0) var flicker: float = 0.0

var _energy: float = 1.0
var _emission: float = 1.0
var _timer: float = 0.0
var _last_tick: int = 0

@onready var _tube: MeshInstance3D = $Tube
@onready var _light: OmniLight3D = $Light
@onready var _hum: AudioStreamPlayer3D = get_node_or_null("Hum")
@onready var _material: StandardMaterial3D = _tube.get_active_material(0).duplicate()


func _ready() -> void:
	if _hum:
		_hum.finished.connect(func() -> void:
			if _light.visible:
				_hum.play())
	_tube.material_override = _material
	_energy = _light.light_energy
	_emission = _material.emission_energy_multiplier
	_apply(1.0 if on else 0.0)
	_timer = randf_range(1.0, 6.0)


func _process(delta: float) -> void:
	if not on or flicker <= 0.0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_stutter()
	_timer = randf_range(1.5, 9.0) / flicker


## Mains power (PowerGrid): off at once; back on with the choke's stuttering start.
func set_power(powered: bool) -> void:
	on = powered
	if powered and is_node_ready():
		_stutter()


func _stutter() -> void:
	var tween := create_tween()
	for i in randi_range(2, 6):
		tween.tween_callback(_apply.bind(randf_range(0.0, 0.3)))
		tween.tween_callback(_tick)
		tween.tween_interval(randf_range(0.02, 0.09))
		tween.tween_callback(_apply.bind(1.0))
		tween.tween_interval(randf_range(0.03, 0.15))


func _tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick < 70 or not is_inside_tree() or not on:
		return
	_last_tick = now
	AudioManager.play_at(LightFlicker.SOUND, _light.global_position, -14.0)


func _apply(level: float) -> void:
	level = 1.0 - (1.0 - level) * SettingsManager.flash_scale()  # Reduce flashing: shallow stutter
	if not on:
		level = 0.0
	_light.light_energy = _energy * level
	_light.visible = level > 0.0
	_material.emission_energy_multiplier = _emission * level
	if _hum and is_inside_tree():
		if level > 0.0 and not _hum.playing:
			_hum.play(randf() * 1.9)
		elif level <= 0.0 and _hum.playing:
			_hum.stop()
