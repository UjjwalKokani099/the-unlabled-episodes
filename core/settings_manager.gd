extends Node
## Global settings store, registered as the autoload "Settings".
##
## React analogy: a context provider backed by localStorage. Any script can read
## `SettingsManager.mouse_sensitivity`, assign to it, and subscribe to `SettingsManager.changed`.
## Every change is saved to user://settings.cfg (one save per frame at most).

signal changed(key: StringName)

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

## Volume setting -> audio bus it controls (buses live in default_bus_layout.tres).
const AUDIO_BUSES := {
	&"master_volume": &"Master",
	&"music_volume": &"Music",
	&"sfx_volume": &"SFX",
	&"ambience_volume": &"Ambience",
	&"voice_volume": &"Voice",
	&"ui_volume": &"UI",
}

## Every persisted key. Add new settings here AND as a var below.
const KEYS: Array[StringName] = [
	&"mouse_sensitivity", &"invert_y", &"fov", &"crouch_toggle", &"head_bob", &"screen_effects",
	&"brightness", &"fullscreen", &"graphics_quality", &"show_fps", &"ps1_mode", &"film_look",
	&"subtitles", &"subtitle_size", &"key_bindings",
	&"master_volume", &"music_volume", &"sfx_volume", &"ambience_volume", &"voice_volume", &"ui_volume",
]

# Declared first so it is already true while the vars below get their initial values:
# setters then do nothing until load_settings() has run.
var _loading := true
var _save_queued := false

## Degrees the camera turns per pixel of mouse movement.
var mouse_sensitivity: float = 0.12:
	set(value):
		mouse_sensitivity = clampf(value, 0.01, 1.0)
		_on_value_set(&"mouse_sensitivity")

var invert_y: bool = false:
	set(value):
		invert_y = value
		_on_value_set(&"invert_y")

## Vertical field of view in degrees.
var fov: float = 75.0:
	set(value):
		fov = clampf(value, 60.0, 100.0)
		_on_value_set(&"fov")

## false = hold to crouch, true = press once to crouch, again to stand.
var crouch_toggle: bool = false:
	set(value):
		crouch_toggle = value
		_on_value_set(&"crouch_toggle")

## Also controls the camera's hand-held sway.
var head_bob: bool = true:
	set(value):
		head_bob = value
		_on_value_set(&"head_bob")

## VHS look strength: 0 = clean picture, 1 = full effect.
var screen_effects: float = 1.0:
	set(value):
		screen_effects = clampf(value, 0.0, 1.0)
		_on_value_set(&"screen_effects")

## Gamma-style brightness: 1.0 = unchanged, higher lifts the shadows.
var brightness: float = 1.0:
	set(value):
		brightness = clampf(value, 0.6, 1.6)
		_on_value_set(&"brightness")

var fullscreen: bool = false:
	set(value):
		fullscreen = value
		_on_value_set(&"fullscreen")

## 0 = Low, 1 = Medium, 2 = High. Applied by the Graphics autoload.
var graphics_quality: int = 1:
	set(value):
		graphics_quality = clampi(value, 0, 2)
		_on_value_set(&"graphics_quality")

var show_fps: bool = false:
	set(value):
		show_fps = value
		_on_value_set(&"show_fps")

## Optional PS1 look: ~480p pixelation + colour banding, vertex wobble, affine warping,
## point-sampled textures (Graphics applies it; off = the default VHS-over-PBR look).
var ps1_mode: bool = false:
	set(value):
		ps1_mode = value
		_on_value_set(&"ps1_mode")

## Grounded "real lens" grade over the 3D view (assets/shaders/film_grade): 0 = off, 1 = full.
var film_look: float = 1.0:
	set(value):
		film_look = clampf(value, 0.0, 1.0)
		_on_value_set(&"film_look")

var subtitles: bool = true:
	set(value):
		subtitles = value
		_on_value_set(&"subtitles")

## 0 = small, 1 = medium, 2 = large.
var subtitle_size: int = 1:
	set(value):
		subtitle_size = clampi(value, 0, 2)
		_on_value_set(&"subtitle_size")

## Rebound keyboard keys: action name -> physical keycode. Only changed actions are stored.
var key_bindings: Dictionary = {}:
	set(value):
		key_bindings = value
		_apply_bindings()
		_on_value_set(&"key_bindings")

## Actions the player may rebind (shown in Settings > Controls).
const REBINDABLE: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint", &"crouch", &"flashlight", &"interact", &"spot", &"night_vision", &"objectives"]

# Volumes are linear 0.0 (silent) .. 1.0 (full).
var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_on_value_set(&"master_volume")

var music_volume: float = 0.8:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_on_value_set(&"music_volume")

var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_on_value_set(&"sfx_volume")

var ambience_volume: float = 1.0:
	set(value):
		ambience_volume = clampf(value, 0.0, 1.0)
		_on_value_set(&"ambience_volume")

var voice_volume: float = 1.0:
	set(value):
		voice_volume = clampf(value, 0.0, 1.0)
		_on_value_set(&"voice_volume")

var ui_volume: float = 0.8:
	set(value):
		ui_volume = clampf(value, 0.0, 1.0)
		_on_value_set(&"ui_volume")


var _brightness_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_brightness_layer()
	load_settings()


func load_settings() -> void:
	_loading = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for key in KEYS:
			if cfg.has_section_key(SECTION, key):
				set(key, cfg.get_value(SECTION, key))
	_loading = false
	for key: StringName in AUDIO_BUSES:
		_apply_volume(key)
	_apply_brightness()
	_apply_fullscreen()


func save_settings() -> void:
	_save_queued = false
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value(SECTION, key, get(key))
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [SAVE_PATH, err])


func _on_value_set(key: StringName) -> void:
	if _loading:
		return
	if AUDIO_BUSES.has(key):
		_apply_volume(key)
	elif key == &"brightness":
		_apply_brightness()
	elif key == &"fullscreen":
		_apply_fullscreen()
	changed.emit(key)
	EventBus.setting_changed.emit(key)
	if not _save_queued:
		_save_queued = true
		save_settings.call_deferred()


func _apply_volume(key: StringName) -> void:
	var bus := AudioServer.get_bus_index(AUDIO_BUSES[key])
	if bus == -1:
		return
	var linear: float = get(key)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(bus, linear <= 0.0)


func _make_brightness_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_brightness_rect = ColorRect.new()
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/brightness.gdshader")
	_brightness_rect.material = material
	layer.add_child(_brightness_rect)


func _apply_brightness() -> void:
	(_brightness_rect.material as ShaderMaterial).set_shader_parameter(&"brightness", brightness)
	_brightness_rect.visible = not is_equal_approx(brightness, 1.0)


func _apply_fullscreen() -> void:
	var current := DisplayServer.window_get_mode()
	var is_full := current == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Bind `action` to one keyboard key (replacing its keyboard keys; other devices kept).
func rebind(action: StringName, physical_keycode: Key) -> void:
	var copy := key_bindings.duplicate()
	copy[String(action)] = int(physical_keycode)
	key_bindings = copy


## The first keyboard key bound to an action, as text for the UI.
func key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			return OS.get_keycode_string(_layout_keycode(key.physical_keycode))
	return "-"


## The key on this keyboard layout at a physical (US-position) key. Web can't map layouts.
func _layout_keycode(physical: Key) -> Key:
	if OS.has_feature("web"):
		return physical
	return DisplayServer.keyboard_get_keycode_from_physical(physical)


func _apply_bindings() -> void:
	for action: String in key_bindings:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var key := InputEventKey.new()
		key.physical_keycode = int(key_bindings[action])
		InputMap.action_add_event(action, key)
