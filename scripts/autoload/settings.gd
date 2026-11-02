extends Node
## Global settings store, registered as the autoload "Settings".
##
## React analogy: a context provider backed by localStorage. Any script can read
## `Settings.mouse_sensitivity`, assign to it, and subscribe to `Settings.changed`.
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
}

## Every persisted key. Add new settings here AND as a var below.
const KEYS: Array[StringName] = [
	&"mouse_sensitivity", &"invert_y", &"fov", &"crouch_toggle", &"head_bob", &"screen_effects",
	&"brightness", &"fullscreen", &"graphics_quality", &"show_fps", &"ps1_mode",
	&"subtitles", &"subtitle_size", &"key_bindings",
	&"master_volume", &"music_volume", &"sfx_volume", &"ambience_volume",
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


var _brightness_rect: ColorRect

## Touch play (iPad / web): true after the first screen touch, false again once a real mouse
## moves. Not saved. In touch mode the mouse is never captured; `mouse_captured()` reports
## what the game asked for instead, so gameplay code works the same with fingers.
var touch_mode: bool = false
var _want_capture: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_brightness_layer()
	load_settings()


## Every "grab / free the mouse" goes through here (player, pause menu, dialogue, inspect...).
func capture_mouse(on: bool) -> void:
	_want_capture = on
	if touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


## True while the game is in "playing" mode (mouse grabbed, or wanted in touch mode).
func mouse_captured() -> bool:
	if touch_mode:
		return _want_capture
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


var _fingers: Dictionary = {}  # touch index -> true while that finger is down
var _last_touch_ms: int = -100000
var _mouse_travel: float = 0.0


## Called for every screen touch / drag (here and by TouchControls, which consumes them).
func note_touch(event: InputEvent) -> void:
	_last_touch_ms = Time.get_ticks_msec()
	_mouse_travel = 0.0
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = true
		else:
			_fingers.erase(event.index)
	if not touch_mode:
		_want_capture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _want_capture
		touch_mode = true
		capture_mouse(_want_capture)
		changed.emit(&"touch_mode")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		note_touch(event)
	elif touch_mode and event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		# Browsers also report finger drags as mouse movement: only a mouse that moves a fair
		# distance with no finger on the screen for a second means a real mouse took over.
		if not _fingers.is_empty() or Time.get_ticks_msec() - _last_touch_ms < 1000:
			return
		_mouse_travel += (event as InputEventMouseMotion).relative.length()
		if _mouse_travel > 80.0:
			touch_mode = false
			_mouse_travel = 0.0
			capture_mouse(_want_capture)
			changed.emit(&"touch_mode")


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
	material.shader = preload("res://shaders/brightness.gdshader")
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
