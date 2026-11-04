class_name LightFlicker
extends RefCounted
## Irregular light flicker shared by FlickerReaction and SequencePlayer (studio spec 11:
## noise-based, not a sine; the sound synced to it). Two layers of value noise: a slow one
## decides when the tube "drops out" (bursts and quiet stretches), a fast one shivers the
## brightness while it's lit. Every drop-out plays the tick/choke buzz at the light.
## Reduce flashing (SettingsManager.flash_scale) makes the dips shallow.

const SOUND := preload("res://assets/audio/sfx/light_flicker.wav")
const MIN_SOUND_GAP := 0.07

var light: Light3D
var base_energy: float = 1.0
var dim_factor: float = 0.04
var sound: AudioStream = SOUND
var volume_db: float = -10.0
var _slow := FastNoiseLite.new()
var _fast := FastNoiseLite.new()
var _t: float = 0.0
var _lit: bool = true
var _since_sound: float = 1.0


func _init(target: Light3D, dim: float = 0.04) -> void:
	light = target  # null = noise only (FlickerReaction's visibility flicker)
	base_energy = target.light_energy if target else 1.0
	dim_factor = dim
	var seed_value := randi()
	for n: FastNoiseLite in [_slow, _fast]:
		n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		n.seed = seed_value
		seed_value += 17
	_slow.frequency = 7.0
	_fast.frequency = 40.0


## Brightness factor at time t (0 = dark .. 1): exposed for tests.
func level_at(t: float) -> float:
	var drop := _slow.get_noise_1d(t)
	if drop < -0.12:
		return dim_factor
	return 0.82 + 0.18 * clampf(_fast.get_noise_1d(t) + 0.5, 0.0, 1.0)


## Advance by delta; returns false once the light is gone.
func step(delta: float) -> bool:
	if not is_instance_valid(light):
		return false
	_t += delta
	_since_sound += delta
	var k := level_at(_t)
	var lit := k > dim_factor + 0.001
	if not lit:  # reduce flashing: shallower drop-outs
		k = lerpf(1.0, k, SettingsManager.flash_scale())
	light.light_energy = base_energy * k
	if _lit and not lit and sound and _since_sound >= MIN_SOUND_GAP and light.is_inside_tree():
		AudioManager.play_at(sound, light.global_position, volume_db)
		_since_sound = 0.0
	_lit = lit
	return true


func restore() -> void:
	if is_instance_valid(light):
		light.light_energy = base_energy


## Flicker `target` for `seconds` (await it), then put its energy back.
static func run(target: Light3D, seconds: float, dim: float = 0.04) -> void:
	var f := LightFlicker.new(target, dim)
	var tree := target.get_tree()
	var elapsed := 0.0
	while elapsed < seconds:
		await tree.process_frame
		var dt := tree.root.get_process_delta_time()
		elapsed += dt
		if not f.step(dt):
			return
	f.restore()
