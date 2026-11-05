extends Node
## Audio playback services, registered as the autoload "AudioManager".
##
## Buses (default_bus_layout.tres): Master > Music, SFX (with the "Space" reverb that
## AcousticZones drive), Ambience, Voice, UI. Volumes come from SettingsManager.
## - play_ui(&"hover" / &"click" / &"back"): menu feedback on the UI bus.
## - play_sfx() / play_at(): one-shots from a small pool of players (no node spam).
## - play_music(stream, fade) / stop_music(fade): one music track with crossfades.
## - set_muffled(true): low-pass on the game buses (pause menu); UI and music stay clear.
## - set_ambience(AmbienceSet): crossfades the place's background beds (~1.5 s); layers shared
##   by both places keep playing and just change level. AcousticZones call it.
## - set_tension(value, source): 0..1 intensity blends three drone layers (low drone,
##   rumble, high cluster). Several sources (story beats, the Cameraman's exposure) each set
##   their own; the highest wins. hold_silence(): everything drops out for a moment (used
##   right before a scare), then comes back.
## - play_voice(line_id): plays assets/audio/voice/<line_id>.ogg if it exists (VO later).

const POOL_2D := 8
const POOL_3D := 12
## Buses that go muffled while the game is paused.
const MUFFLED_BUSES: Array[StringName] = [&"SFX", &"Ambience", &"Voice"]
const MUFFLE_CUTOFF_HZ := 900.0
const AMBIENCE_FADE := 1.5
const SILENT_DB := -60.0
## Tension layers: stream, level at full intensity (dB), intensity where it starts, curve power.
const TENSION_LAYERS := [
	[preload("res://assets/audio/tension/drone_low.ogg"), -4.0, 0.0, 1.0],
	[preload("res://assets/audio/tension/rumble.ogg"), -2.0, 0.25, 1.5],
	[preload("res://assets/audio/tension/drone_high.ogg"), -8.0, 0.55, 1.0],
]
const VOICE_DIR := "res://assets/audio/voice/"
const UI_SOUNDS := {
	&"hover": preload("res://assets/audio/sfx/ui_blip.wav"),
	&"click": preload("res://assets/audio/sfx/ui_select.wav"),
	&"back": preload("res://assets/audio/sfx/vcr_click.wav"),
	&"objective": preload("res://assets/audio/sfx/objective_update.wav"),
}

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _ui: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_tween: Tween
var _muffled: bool = false
## Ambience / tension players fade towards a target level each frame (dB per second rates).
var _ambience_players: Dictionary = {}  # AudioStream -> AudioStreamPlayer
var _ambience_targets: Dictionary = {}  # AudioStreamPlayer -> float dB
var _ambience: AmbienceSet
var _tension_players: Array[AudioStreamPlayer] = []
var _tension_sources: Dictionary = {}  # StringName -> 0..1
var _tension: float = 0.0
var _tension_rate: float = 0.5  # intensity units per second
var _duck_db: float = 0.0
var _duck_tween: Tween
var _voice: AudioStreamPlayer
var _shut_down: bool = false


## Every voice line id the game asked for this session (tests compare with data/voice/lines.json).
var voice_requests: PackedStringArray = []

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
	for i in TENSION_LAYERS.size():
		var t := AudioStreamPlayer.new()
		t.name = "Tension%d" % i
		t.bus = &"Music"
		t.stream = TENSION_LAYERS[i][0]
		t.volume_db = SILENT_DB
		add_child(t)
		_tension_players.append(t)
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.bus = &"Voice"
	add_child(_voice)
	# A new scene starts quiet: its zones set their own ambience, its story its tension.
	EventBus.scene_transition_started.connect(func(_path: String) -> void:
		set_ambience(null, 0.5)
		_tension_sources.clear())


func _process(delta: float) -> void:
	if _shut_down:
		return
	# Ambience: every layer eases towards its target; silent ones stop.
	for p: AudioStreamPlayer in _ambience_targets.keys():
		var target: float = _ambience_targets[p]
		var rate: float = p.get_meta(&"rate", absf(SILENT_DB) / AMBIENCE_FADE)
		var level := move_toward(p.get_meta(&"level", SILENT_DB), target, delta * rate)
		p.set_meta(&"level", level)
		p.volume_db = level + _duck_db
		if level <= SILENT_DB + 0.1 and target <= SILENT_DB:
			p.stop()
			_ambience_targets.erase(p)
	# Tension: the highest source wins, approached at _tension_rate.
	var want := 0.0
	for v: float in _tension_sources.values():
		want = maxf(want, v)
	_tension = move_toward(_tension, want, delta * _tension_rate)
	for i in _tension_players.size():
		var layer: Array = TENSION_LAYERS[i]
		var amount := clampf((_tension - float(layer[2])) / (1.0 - float(layer[2])), 0.0, 1.0)
		var t := _tension_players[i]
		if amount <= 0.001:
			if t.playing:
				t.stop()
			continue
		if not t.playing:
			t.play()
		t.volume_db = lerpf(SILENT_DB, float(layer[1]), pow(amount, float(layer[3])) ** 0.35) + _duck_db

## Menu sound: &"hover", &"click" or &"back".
func play_ui(kind: StringName) -> void:
	var stream: AudioStream = UI_SOUNDS.get(kind)
	if stream == null:
		return
	_ui.stream = stream
	_ui.volume_db = -14.0 if kind == &"hover" else (-10.0 if kind == &"objective" else -8.0)
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


## A clip from a SoundSet (no back-to-back repeats, pitch jitter) at a world position.
func play_set_at(set: SoundSet, position: Vector3, volume_db: float = 0.0, unit_size: float = 3.0) -> AudioStreamPlayer3D:
	if set == null or set.streams.is_empty():
		return null
	var p := play_at(set.pick(), position, set.volume_db + volume_db, unit_size)
	p.pitch_scale = set.random_pitch()
	return p


## A clip from a SoundSet, not positional.
func play_set(set: SoundSet, volume_db: float = 0.0, bus: StringName = &"SFX") -> AudioStreamPlayer:
	if set == null or set.streams.is_empty():
		return null
	return play_sfx(set.pick(), set.volume_db + volume_db, bus, set.random_pitch())


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


## Quitting: stop every player and ignore later requests (zones fire as the level frees).
func shutdown() -> void:
	_shut_down = true
	_tension_sources.clear()
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
		elif child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()
			(child as AudioStreamPlayer3D).stream = null
	_ambience_players.clear()
	_ambience_targets.clear()


## Crossfades to a place's beds (null = fade everything out).
func set_ambience(set: AmbienceSet, fade: float = AMBIENCE_FADE) -> void:
	if _shut_down:
		return
	_ambience = set
	var wanted := {}
	if set:
		for i in set.layers.size():
			var stream := set.layers[i]
			if stream == null:
				continue
			wanted[stream] = set.volume_of(i)
	for stream: AudioStream in _ambience_players.keys():
		var p: AudioStreamPlayer = _ambience_players[stream]
		if not wanted.has(stream):
			if p.playing:
				_retarget(p, SILENT_DB, fade)
	for stream: AudioStream in wanted:
		var p: AudioStreamPlayer = _ambience_players.get(stream)
		if p == null:
			p = AudioStreamPlayer.new()
			p.bus = &"Ambience"
			p.stream = stream
			add_child(p)
			_ambience_players[stream] = p
		if not p.playing:
			p.set_meta(&"level", SILENT_DB)
			p.volume_db = SILENT_DB
			p.play(randf() * maxf(stream.get_length() - 0.1, 0.0))
		_retarget(p, wanted[stream], fade)
	if fade <= 0.0:
		for p: AudioStreamPlayer in _ambience_targets.keys():
			p.set_meta(&"level", _ambience_targets[p])


## Every layer change takes the whole fade time, however small (a real crossfade).
func _retarget(p: AudioStreamPlayer, target_db: float, fade: float) -> void:
	var level: float = p.get_meta(&"level", SILENT_DB)
	p.set_meta(&"rate", maxf(absf(target_db - level) / maxf(fade, 0.01), 1.0))
	_ambience_targets[p] = target_db


func current_ambience() -> AmbienceSet:
	return _ambience


## Level (dB, before ducking) of an ambience layer, or SILENT_DB if it isn't playing.
func ambience_level(stream: AudioStream) -> float:
	var p: AudioStreamPlayer = _ambience_players.get(stream)
	return float(p.get_meta(&"level", SILENT_DB)) if p and p.playing else SILENT_DB


## Tension 0..1 from one `source` (story beats, the stalker...). The highest source wins;
## the mix moves at `rate` intensity per second (0.5 = calm to full in 2 s).
func set_tension(value: float, source: StringName = &"story", rate: float = 0.5) -> void:
	_tension_sources[source] = clampf(value, 0.0, 1.0)
	_tension_rate = maxf(rate, 0.01)


func tension() -> float:
	return _tension


## Silence before a scare: ambience and tension drop out over `fade_out`, stay away for
## `seconds`, then return over `fade_in`. Await it if the scare should land in the silence.
func hold_silence(seconds: float, fade_out: float = 0.6, fade_in: float = 2.0) -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(self, "_duck_db", -40.0, fade_out)
	_duck_tween.tween_interval(seconds)
	_duck_tween.tween_property(self, "_duck_db", 0.0, fade_in)
	await get_tree().create_timer(fade_out + seconds, true).timeout


func is_silenced() -> bool:
	return _duck_db < -20.0


## Plays a recorded voice line (assets/audio/voice/<line_id>.ogg) on the Voice bus.
## Returns its length in seconds, or 0 when there is no recording yet (subtitles only).
func play_voice(line_id: String) -> float:
	if line_id == "":
		return 0.0
	if voice_requests.size() < 2000:
		voice_requests.append(line_id)  # tests check every id is in the voice script
	var path := VOICE_DIR + line_id + ".ogg"
	if not ResourceLoader.exists(path):
		return 0.0
	var stream := load(path) as AudioStream
	_voice.stream = stream
	_voice.play()
	return stream.get_length()


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
