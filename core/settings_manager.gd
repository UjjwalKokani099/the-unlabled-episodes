extends Node
## Global settings store, registered as the autoload "SettingsManager".
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
	&"mouse_sensitivity", &"invert_y", &"fov", &"crouch_toggle", &"sprint_toggle", &"head_bob_intensity", &"camera_sway",
	&"reduce_camera_motion", &"screen_effects", &"controller_sensitivity", &"show_objectives", &"reduce_flashing",
	&"window_mode", &"resolution", &"vsync", &"fps_cap", &"mono_audio",
	&"render_scale", &"anti_aliasing", &"shadow_quality", &"texture_quality", &"fog_quality", &"effects_quality",
	&"film_grain", &"chromatic_aberration", &"vignette", &"tape_blur",
	&"brightness", &"graphics_quality", &"show_fps", &"ps1_mode", &"film_look",
	&"subtitles", &"subtitle_size", &"subtitle_bg_opacity", &"key_bindings",
	&"master_volume", &"music_volume", &"sfx_volume", &"ambience_volume", &"voice_volume", &"ui_volume",
]

# Declared first so it is already true while the vars below get their initial values:
# setters then do nothing until load_settings() has run.
var _loading := true
var _save_queued := false
var _applying_preset := false
var _mono_effect: AudioEffectStereoEnhance
var _applied_vsync: bool = true

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
		fov = clampf(value, 60.0, 90.0)
		_on_value_set(&"fov")

## false = hold to crouch, true = press once to crouch, again to stand.
var crouch_toggle: bool = false:
	set(value):
		crouch_toggle = value
		_on_value_set(&"crouch_toggle")

## false = hold to run, true = press once to run, again to walk (accessibility).
var sprint_toggle: bool = false:
	set(value):
		sprint_toggle = value
		_on_value_set(&"sprint_toggle")

## 0 = no head bob .. 1 = full (scaled further by reduce_camera_motion).
var head_bob_intensity: float = 1.0:
	set(value):
		head_bob_intensity = clampf(value, 0.0, 1.0)
		_on_value_set(&"head_bob_intensity")

## Hand-held camera sway + breathing while standing still.
var camera_sway: bool = true:
	set(value):
		camera_sway = value
		_on_value_set(&"camera_sway")

## Accessibility: smaller bob, no sway / strafe tilt / sprint FOV kick, softer shakes.
var reduce_camera_motion: bool = false:
	set(value):
		reduce_camera_motion = value
		_on_value_set(&"reduce_camera_motion")

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

## Graphics presets: picking one writes these detail settings; changing any detail setting
## afterwards turns the preset into CUSTOM (3). GraphicsManager applies the details.
const GRAPHICS_PRESETS := [
	{"render_scale": 0.6, "anti_aliasing": 0, "shadow_quality": 0, "texture_quality": 0, "fog_quality": 0, "effects_quality": 0},
	{"render_scale": 0.75, "anti_aliasing": 1, "shadow_quality": 1, "texture_quality": 1, "fog_quality": 1, "effects_quality": 1},
	{"render_scale": 0.9, "anti_aliasing": 1, "shadow_quality": 2, "texture_quality": 2, "fog_quality": 2, "effects_quality": 2},
]
const QUALITY_CUSTOM := 3
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const FPS_CAPS: Array[int] = [30, 60, 120, 144, 0]
enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

## 0 = Low, 1 = Medium, 2 = High, 3 = Custom. Auto-detected on first launch.
var graphics_quality: int = 1:
	set(value):
		graphics_quality = clampi(value, 0, QUALITY_CUSTOM)
		if graphics_quality < QUALITY_CUSTOM and not _loading:
			_apply_preset(graphics_quality)
		_on_value_set(&"graphics_quality")

## Graphics details (part of the preset; editing one makes the preset CUSTOM).
var render_scale: float = 0.75:
	set(value):
		render_scale = clampf(value, 0.5, 1.0)
		_detail_changed(&"render_scale")
## 0 off, 1 FXAA, 2 MSAA 2x, 3 MSAA 4x.
var anti_aliasing: int = 1:
	set(value):
		anti_aliasing = clampi(value, 0, 3)
		_detail_changed(&"anti_aliasing")
## 0..2 = low / medium / high for each.
var shadow_quality: int = 1:
	set(value):
		shadow_quality = clampi(value, 0, 2)
		_detail_changed(&"shadow_quality")
var texture_quality: int = 1:
	set(value):
		texture_quality = clampi(value, 0, 2)
		_detail_changed(&"texture_quality")
## 0 = no volumetric fog.
var fog_quality: int = 1:
	set(value):
		fog_quality = clampi(value, 0, 2)
		_detail_changed(&"fog_quality")
## Ambient occlusion / indirect light / reflections / baked GI: 0 off, 1 some, 2 all.
var effects_quality: int = 1:
	set(value):
		effects_quality = clampi(value, 0, 2)
		_detail_changed(&"effects_quality")

## Post-processing switches (film look + tape look).
var film_grain: bool = true:
	set(value):
		film_grain = value
		_on_value_set(&"film_grain")
var chromatic_aberration: bool = true:
	set(value):
		chromatic_aberration = value
		_on_value_set(&"chromatic_aberration")
var vignette: bool = true:
	set(value):
		vignette = value
		_on_value_set(&"vignette")
## The camcorder tape's horizontal smear.
var tape_blur: bool = true:
	set(value):
		tape_blur = value
		_on_value_set(&"tape_blur")

## Display.
var window_mode: int = WindowMode.WINDOWED:
	set(value):
		window_mode = clampi(value, 0, 2)
		_on_value_set(&"window_mode")
## Index into RESOLUTIONS (window size in windowed mode).
var resolution: int = 0:
	set(value):
		resolution = clampi(value, 0, RESOLUTIONS.size() - 1)
		_on_value_set(&"resolution")
var vsync: bool = true:
	set(value):
		vsync = value
		_on_value_set(&"vsync")
## Index into FPS_CAPS (last = unlimited).
var fps_cap: int = 4:
	set(value):
		fps_cap = clampi(value, 0, FPS_CAPS.size() - 1)
		_on_value_set(&"fps_cap")

## Audio: everything in the middle (one-ear listening).
var mono_audio: bool = false:
	set(value):
		mono_audio = value
		_on_value_set(&"mono_audio")

## Controls: right-stick look speed (x 120 degrees per second).
var controller_sensitivity: float = 1.0:
	set(value):
		controller_sensitivity = clampf(value, 0.2, 3.0)
		_on_value_set(&"controller_sensitivity")

## Gameplay: the objective list in the corner.
var show_objectives: bool = true:
	set(value):
		show_objectives = value
		_on_value_set(&"show_objectives")

## Accessibility: gentler light flicker, tape glitches and static flashes.
var reduce_flashing: bool = false:
	set(value):
		reduce_flashing = value
		_on_value_set(&"reduce_flashing")

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

## 0 = small, 1 = medium, 2 = large, 3 = XL.
var subtitle_size: int = 1:
	set(value):
		subtitle_size = clampi(value, 0, 3)
		_on_value_set(&"subtitle_size")

## Opacity of the black box behind subtitles (accessibility: 0 = none, 1 = solid).
var subtitle_bg_opacity: float = 0.55:
	set(value):
		subtitle_bg_opacity = clampf(value, 0.0, 1.0)
		_on_value_set(&"subtitle_bg_opacity")

## Rebound keyboard keys: action name -> physical keycode. Only changed actions are stored.
var key_bindings: Dictionary = {}:
	set(value):
		key_bindings = value
		_apply_bindings()
		_on_value_set(&"key_bindings")

## Actions the player may rebind (shown in Settings > Controls).
const REBINDABLE: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint", &"crouch", &"flashlight", &"interact", &"spot", &"night_vision", &"objectives", &"phone"]

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


## Multiplier for flashes, flicker depth and glitches (reduce flashing -> 0.35).
func flash_scale() -> float:
	return 0.35 if reduce_flashing else 1.0


## The window size for windowed mode.
func window_size() -> Vector2i:
	return RESOLUTIONS[resolution]


## Best preset for this machine (first launch): web and integrated graphics -> Low,
## RTX / recent Radeon RX -> High, anything else -> Medium.
static func detect_quality() -> int:
	if OS.has_feature("web"):
		return 0
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	for weak in ["intel", "uhd", "iris", "llvmpipe", "swiftshader", "radeon(tm) graphics", "vega", "mali", "adreno"]:
		if weak in gpu:
			return 0
	for strong in ["rtx", "rx 6", "rx 7", "rx 9", "arc a7"]:
		if strong in gpu:
			return 2
	return 1


func _apply_preset(level: int) -> void:
	var preset: Dictionary = GRAPHICS_PRESETS[level]
	_applying_preset = true
	for key: String in preset:
		set(key, preset[key])
	_applying_preset = false


## A detail setting changed: the preset becomes the one it now matches, or CUSTOM.
func _detail_changed(key: StringName) -> void:
	if not _loading and not _applying_preset:
		var match_level := QUALITY_CUSTOM
		for i in GRAPHICS_PRESETS.size():
			var same := true
			for k: String in GRAPHICS_PRESETS[i]:
				if not is_equal_approx(float(get(k)), float(GRAPHICS_PRESETS[i][k])):
					same = false
					break
			if same:
				match_level = i
				break
		if match_level != graphics_quality:
			graphics_quality = match_level  # emits its own change; no preset re-apply for CUSTOM
	_on_value_set(key)


## Multiplier for head bob and other camera motion (0..1).
func motion_scale() -> float:
	return head_bob_intensity * (0.35 if reduce_camera_motion else 1.0)


## True when the hand-held sway, strafe tilt and FOV kick should play.
func sway_allowed() -> bool:
	return camera_sway and not reduce_camera_motion


func load_settings() -> void:
	_loading = true
	var cfg := ConfigFile.new()
	var first_launch := cfg.load(SAVE_PATH) != OK
	if not first_launch:
		for key in KEYS:
			if cfg.has_section_key(SECTION, key):
				set(key, cfg.get_value(SECTION, key))
		# Older settings files: fullscreen on/off -> window mode; presets had no details.
		if cfg.has_section_key(SECTION, "fullscreen") and not cfg.has_section_key(SECTION, "window_mode"):
			window_mode = WindowMode.BORDERLESS if cfg.get_value(SECTION, "fullscreen") else WindowMode.WINDOWED
		if not cfg.has_section_key(SECTION, "render_scale") and graphics_quality < QUALITY_CUSTOM:
			_apply_preset(graphics_quality)
	else:
		graphics_quality = detect_quality()
		_apply_preset(graphics_quality)
		resolution = _native_resolution_index()
	_loading = false
	for key: StringName in AUDIO_BUSES:
		_apply_volume(key)
	_apply_brightness()
	_apply_display()
	_apply_mono()


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
	elif key in [&"window_mode", &"resolution", &"vsync", &"fps_cap"]:
		_apply_display()
	elif key == &"mono_audio":
		_apply_mono()
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


func _apply_display() -> void:
	Engine.max_fps = FPS_CAPS[fps_cap]
	if DisplayServer.get_name() == "headless":
		return
	# Only when it differs from what the window already got from project.godot (VSync on):
	# some drivers refuse any change and warn.
	if vsync != _applied_vsync:
		_applied_vsync = vsync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if OS.has_feature("web"):
		return  # the browser owns the window (fullscreen = the page's own button)
	var want: DisplayServer.WindowMode = [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][window_mode]
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if window_mode == WindowMode.WINDOWED:
		var screen := DisplayServer.screen_get_size()
		var size := Vector2i(mini(window_size().x, screen.x), mini(window_size().y, screen.y))
		if DisplayServer.window_get_size() != size:
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position((screen - size) / 2 + DisplayServer.screen_get_position())


## Mono audio = a stereo "enhancer" on Master with zero side signal.
func _apply_mono() -> void:
	if _mono_effect == null:
		_mono_effect = AudioEffectStereoEnhance.new()
		_mono_effect.pan_pullout = 0.0
		AudioServer.add_bus_effect(0, _mono_effect)
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _mono_effect:
			AudioServer.set_bus_effect_enabled(0, i, mono_audio)


## The largest listed resolution that fits this screen (first launch).
func _native_resolution_index() -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	var screen := DisplayServer.screen_get_size()
	var best := 0
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i].x < screen.x and RESOLUTIONS[i].y < screen.y:
			best = i
	return best


## Bind `action` to one keyboard key (replacing its keyboard keys; other devices kept).
## If another action already uses that key, the two swap keys (no silent double binding).
## Returns the action that gave up the key, or &"" when there was no conflict.
func rebind(action: StringName, physical_keycode: Key) -> StringName:
	var copy := key_bindings.duplicate()
	var old_key := physical_key_of(action)
	var swapped: StringName = &""
	for other in REBINDABLE:
		if other != action and physical_key_of(other) == physical_keycode:
			swapped = other
			copy[String(other)] = int(old_key)
	copy[String(action)] = int(physical_keycode)
	key_bindings = copy
	return swapped


## Back to the keys in project.godot.
func reset_bindings() -> void:
	key_bindings = {}
	InputMap.load_from_project_settings()
	InputManager.add_gamepad_map()


## The physical key bound to an action (KEY_NONE when it has none).
func physical_key_of(action: StringName) -> Key:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			return key.physical_keycode
	return KEY_NONE


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
