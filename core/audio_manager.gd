extends Node
## Audio playback services, registered as the autoload "AudioManager".
##
## Buses (default_bus_layout.tres): Master > Music, SFX (with the "Space" reverb that
## AcousticZones drive), Ambience, Voice, UI. Volumes come from SettingsManager.
## - play_ui(&"hover" / &"click" / &"back"): menu feedback on the UI bus.
## - play_sfx() / play_at(): one-shots from a small pool of players (no node spam).
## - play_music(stream, fade) / stop_music(fade): one music track with crossfades.
## - set_muffled(true): low-pass on the game buses (pause menu); UI and music stay clear.

const POOL_2D := 8
const POOL_3D := 12
## Buses that go muffled while the game is paused.
const MUFFLED_BUSES: Array[StringName] = [&"SFX", &"Ambience", &"Voice"]
const MUFFLE_CUTOFF_HZ := 900.0
const UI_SOUNDS := {
	&"hover": preload("res://assets/audio/sfx/ui_blip.wav"),
	&"click": preload("res://assets/audio/sfx/ui_select.wav"),
	&"back": preload("res://assets/audio/sfx/vcr_click.wav"),
}

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _ui: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_tween: Tween
var _muffled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.name = "OneShot%d" % i
		add_child(p)
		_pool_2d.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "OneShot3D%d" % i
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p3)
		_pool_3d.append(p3)
	_ui = AudioStreamPlayer.new()
	_ui.name = "UI"
	_ui.bus = &"UI"
	add_child(_ui)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = &"Music"
	add_child(_music)


## Menu sound: &"hover", &"click" or &"back".
func play_ui(kind: StringName) -> void:
	var stream: AudioStream = UI_SOUNDS.get(kind)
	if stream == null:
		return
	_ui.stream = stream
	_ui.volume_db = -14.0 if kind == &"hover" else -8.0
	_ui.pitch_scale = randf_range(0.97, 1.03)
	_ui.play()


## Non-positional one-shot (e.g. a stinger) on `bus`. Returns the player used.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, bus: StringName = &"SFX", pitch: float = 1.0) -> AudioStreamPlayer:
	var p := _free_2d()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = bus
	p.pitch_scale = pitch
	p.play()
	return p


## Positional one-shot at `position` (world space). Returns the player used.
func play_at(stream: AudioStream, position: Vector3, volume_db: float = 0.0, unit_size: float = 3.0,
		bus: StringName = &"SFX") -> AudioStreamPlayer3D:
	var p := _free_3d()
	p.stream = stream
	p.global_position = position
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.bus = bus
	p.play()
	return p


## Fades `stream` in on the Music bus over `fade` seconds (crossfading any current track).
func play_music(stream: AudioStream, fade: float = 4.0, volume_db: float = 0.0) -> void:
	if _music.stream == stream and _music.playing:
		return
	_kill_music_tween()
	_music.stream = stream
	_music.volume_db = -60.0
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", volume_db, fade).set_trans(Tween.TRANS_SINE)


func stop_music(fade: float = 1.5) -> void:
	if not _music.playing:
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
	_music_tween.tween_callback(_music.stop)


func is_music_playing() -> bool:
	return _music.playing


## Low-pass the game buses (pause menu), or clear them again.
func set_muffled(on: bool) -> void:
	if on == _muffled:
		return
	_muffled = on
	for bus_name in MUFFLED_BUSES:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0:
			continue
		for i in AudioServer.get_bus_effect_count(bus):
			var effect := AudioServer.get_bus_effect(bus, i)
			if effect is AudioEffectLowPassFilter:
				(effect as AudioEffectLowPassFilter).cutoff_hz = MUFFLE_CUTOFF_HZ
				AudioServer.set_bus_effect_enabled(bus, i, on)


func is_muffled() -> bool:
	return _muffled


func _free_2d() -> AudioStreamPlayer:
	for p in _pool_2d:
		if not p.playing:
			return p
	return _pool_2d[0]  # all busy: steal the oldest slot


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	return _pool_3d[0]


func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
