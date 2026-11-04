class_name SettingsMenu
extends Control
## Settings screen (main menu + pause menu): six tabs (GRAPHICS, DISPLAY, AUDIO, CONTROLS,
## GAMEPLAY, ACCESSIBILITY). Rows come from ROWS (one line per setting), one rebind row per
## SettingsManager.REBINDABLE action, and button rows (calibrate brightness, reset controls).
## Every change goes straight into the Settings store, which saves; rows refresh whenever a
## setting changes (a detail change flips the preset to CUSTOM, a preset moves the details).
## Hosts call open(), and close() on Esc; `closed` fires either way.

signal closed

const TABS := ["GRAPHICS", "DISPLAY", "AUDIO", "CONTROLS", "GAMEPLAY", "ACCESSIBILITY"]
enum Tab { GRAPHICS, DISPLAY, AUDIO, CONTROLS, GAMEPLAY, ACCESSIBILITY }
const LEVELS := ["LOW", "MEDIUM", "HIGH"]
## Sliders need min/max/step; "percent" shows 0..1 as 0..100%; "names" labels int steps
## (a Callable is called for the list); "desktop" rows are hidden in the web build.
const ROWS: Array[Dictionary] = [
	{"tab": Tab.GRAPHICS, "key": &"graphics_quality", "label": "Quality preset", "min": 0.0, "max": 3.0, "step": 1.0, "names": ["LOW", "MEDIUM", "HIGH", "CUSTOM"]},
	{"tab": Tab.GRAPHICS, "key": &"render_scale", "label": "Render scale", "min": 0.5, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.GRAPHICS, "key": &"anti_aliasing", "label": "Anti-aliasing", "min": 0.0, "max": 3.0, "step": 1.0, "names": ["OFF", "FXAA", "MSAA 2X", "MSAA 4X"]},
	{"tab": Tab.GRAPHICS, "key": &"shadow_quality", "label": "Shadows", "min": 0.0, "max": 2.0, "step": 1.0, "names": LEVELS},
	{"tab": Tab.GRAPHICS, "key": &"texture_quality", "label": "Textures", "min": 0.0, "max": 2.0, "step": 1.0, "names": LEVELS},
	{"tab": Tab.GRAPHICS, "key": &"fog_quality", "label": "Fog", "min": 0.0, "max": 2.0, "step": 1.0, "names": LEVELS},
	{"tab": Tab.GRAPHICS, "key": &"effects_quality", "label": "Lighting effects", "min": 0.0, "max": 2.0, "step": 1.0, "names": LEVELS},
	{"tab": Tab.GRAPHICS, "key": &"screen_effects", "label": "VHS effect", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.GRAPHICS, "key": &"film_look", "label": "Film look", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.GRAPHICS, "key": &"film_grain", "label": "Film grain"},
	{"tab": Tab.GRAPHICS, "key": &"chromatic_aberration", "label": "Chromatic aberration"},
	{"tab": Tab.GRAPHICS, "key": &"vignette", "label": "Vignette"},
	{"tab": Tab.GRAPHICS, "key": &"tape_blur", "label": "Tape blur"},
	{"tab": Tab.GRAPHICS, "key": &"ps1_mode", "label": "PS1 mode"},
	{"tab": Tab.GRAPHICS, "key": &"show_fps", "label": "Show FPS"},
	{"tab": Tab.DISPLAY, "key": &"window_mode", "label": "Window mode", "min": 0.0, "max": 2.0, "step": 1.0, "names": ["WINDOWED", "BORDERLESS", "FULLSCREEN"], "desktop": true},
	{"tab": Tab.DISPLAY, "key": &"resolution", "label": "Resolution", "min": 0.0, "max": 5.0, "step": 1.0, "names": "resolution_names", "desktop": true},
	{"tab": Tab.DISPLAY, "key": &"vsync", "label": "VSync", "desktop": true},
	{"tab": Tab.DISPLAY, "key": &"fps_cap", "label": "Frame rate cap", "min": 0.0, "max": 4.0, "step": 1.0, "names": ["30", "60", "120", "144", "NONE"], "desktop": true},
	{"tab": Tab.DISPLAY, "key": &"brightness", "label": "Brightness", "min": 0.6, "max": 1.6, "step": 0.05, "fmt": "%.2f"},
	{"tab": Tab.DISPLAY, "button": &"calibrate", "label": "Calibrate brightness", "text": "CALIBRATE"},
	{"tab": Tab.DISPLAY, "key": &"fov", "label": "Field of view", "min": 60.0, "max": 90.0, "step": 1.0, "fmt": "%d"},
	{"tab": Tab.AUDIO, "key": &"master_volume", "label": "Master volume", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.AUDIO, "key": &"music_volume", "label": "Music", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.AUDIO, "key": &"sfx_volume", "label": "Sound effects", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.AUDIO, "key": &"ambience_volume", "label": "Ambience", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.AUDIO, "key": &"voice_volume", "label": "Voice", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.AUDIO, "key": &"ui_volume", "label": "Menu sounds", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.AUDIO, "key": &"mono_audio", "label": "Mono audio"},
	{"tab": Tab.CONTROLS, "key": &"mouse_sensitivity", "label": "Mouse sensitivity", "min": 0.02, "max": 0.6, "step": 0.01, "fmt": "%.2f"},
	{"tab": Tab.CONTROLS, "key": &"controller_sensitivity", "label": "Controller sensitivity", "min": 0.2, "max": 3.0, "step": 0.1, "fmt": "%.1f"},
	{"tab": Tab.CONTROLS, "key": &"invert_y", "label": "Invert look Y"},
	{"tab": Tab.CONTROLS, "key": &"crouch_toggle", "label": "Toggle crouch"},
	{"tab": Tab.CONTROLS, "key": &"sprint_toggle", "label": "Toggle run"},
	{"tab": Tab.GAMEPLAY, "key": &"show_objectives", "label": "Show objectives"},
	{"tab": Tab.GAMEPLAY, "key": &"head_bob_intensity", "label": "Head bob", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.GAMEPLAY, "key": &"camera_sway", "label": "Camera sway"},
	{"tab": Tab.ACCESSIBILITY, "key": &"subtitles", "label": "Subtitles"},
	{"tab": Tab.ACCESSIBILITY, "key": &"subtitle_size", "label": "Subtitle size", "min": 0.0, "max": 3.0, "step": 1.0, "names": ["SMALL", "MEDIUM", "LARGE", "XL"]},
	{"tab": Tab.ACCESSIBILITY, "key": &"subtitle_bg_opacity", "label": "Subtitle background", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": Tab.ACCESSIBILITY, "key": &"reduce_camera_motion", "label": "Reduce camera motion"},
	{"tab": Tab.ACCESSIBILITY, "key": &"reduce_flashing", "label": "Reduce flashing"},
]
const ACTION_NAMES := {&"move_forward": "Move forward", &"move_back": "Move back", &"move_left": "Move left",
	&"move_right": "Move right", &"sprint": "Sprint", &"crouch": "Crouch", &"flashlight": "Flashlight",
	&"interact": "Use / interact", &"spot": "Pause tape (spot him)", &"night_vision": "Night vision", &"objectives": "Show objectives", &"phone": "Raise phone"}
## Row text size: larger on the CRT (the menu's SubViewport is shrunk onto the screen).
const ROW_FONT_SIZE := 22
const ROW_FONT_SIZE_CRT := 30

## Setting key (or action name / button id) -> its control, for refresh and tests.
var controls: Dictionary = {}
var current_tab: int = 0
## The calibration overlay (null until first opened).
var calibration: BrightnessCalibration
var _value_labels: Dictionary = {}
var _rows_by_key: Dictionary = {}
var _row_nodes: Array = []  # [tab, [nodes]]
var _waiting_action: StringName = &""
var _tabs: TabBar
var _note: Label

@onready var _rows: GridContainer = $Panel/VBox/Scroll/Rows
@onready var _scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var _back: Button = $Panel/VBox/BackList/Back


func _ready() -> void:
	visible = false
	_tabs = TabBar.new()
	_tabs.clip_tabs = false
	for t in TABS:
		_tabs.add_tab(t)
	_tabs.add_theme_font_size_override(&"font_size", _row_size() - 2)
	_tabs.tab_changed.connect(show_tab)
	$Panel/VBox.add_child(_tabs)
	$Panel/VBox.move_child(_tabs, 1)
	var web := OS.has_feature("web")
	for row in ROWS:
		if row.get("desktop", false) and web:
			continue
		if row.has("button"):
			_add_button_row(row)
		else:
			_add_row(row)
	for action in SettingsManager.REBINDABLE:
		_add_rebind_row(action)
	_add_button_row({"tab": Tab.CONTROLS, "button": &"reset_controls", "label": "Default keys", "text": "RESET"})
	_note = Label.new()
	_note.add_theme_font_size_override(&"font_size", _row_size() - 6)
	_note.modulate = Color(1, 1, 1, 0.7)
	$Panel/VBox.add_child(_note)
	$Panel/VBox.move_child(_note, $Panel/VBox.get_child_count() - 2)
	_back.pressed.connect(close)
	SettingsManager.changed.connect(_on_setting_changed)
	show_tab(0)


func open() -> void:
	refresh()
	visible = true
	show_tab(current_tab)


## Esc: ends the brightness calibration first; `force` closes everything (pause menu leaving).
func close(force: bool = false) -> void:
	if calibration and calibration.visible:
		calibration.finish()
		if not force:
			return
	if not visible:
		return
	_waiting_action = &""
	visible = false
	closed.emit()


## True while a rebind row waits for the new key (Esc then cancels the rebind only).
func is_waiting_for_key() -> bool:
	return _waiting_action != &""


func tab_index(tab_name: String) -> int:
	return TABS.find(tab_name)


func show_tab(index: int) -> void:
	current_tab = index
	_tabs.set_current_tab(index)
	var first: Control = null
	for entry in _row_nodes:
		for node: Control in entry[1]:
			node.visible = entry[0] == index
			if entry[0] == index and first == null and (node is Range or node is BaseButton):
				first = node
	_scroll.scroll_vertical = 0
	_note.text = "Display options are set by your browser." if index == Tab.DISPLAY and OS.has_feature("web") else ""
	if first and visible:
		first.grab_focus()


func refresh() -> void:
	for key: StringName in _rows_by_key:
		_refresh_row(_rows_by_key[key])
	for action in SettingsManager.REBINDABLE:
		(controls[action] as Button).text = SettingsManager.key_name(action)


## Opens the brightness calibration overlay (DISPLAY tab button).
func open_calibration() -> void:
	if calibration == null:
		calibration = BrightnessCalibration.new()
		calibration.font_size = _row_size()
		add_child(calibration)
		calibration.finished.connect(func() -> void: (controls[&"calibrate"] as Button).grab_focus())
	calibration.open()


func _on_setting_changed(key: StringName) -> void:
	if _rows_by_key.has(key):
		_refresh_row(_rows_by_key[key])


func _refresh_row(row: Dictionary) -> void:
	var control: Control = controls[row.key]
	if control is HSlider:
		(control as HSlider).set_value_no_signal(SettingsManager.get(row.key))
	else:
		(control as CheckButton).set_pressed_no_signal(SettingsManager.get(row.key))
	_update_value_label(row)


func _input(event: InputEvent) -> void:
	if _waiting_action == &"" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	var action := _waiting_action
	_waiting_action = &""
	if key.physical_keycode != KEY_ESCAPE:
		var swapped := SettingsManager.rebind(action, key.physical_keycode)
		if swapped != &"":
			_note.text = "%s was on that key: it now uses %s." % [ACTION_NAMES.get(swapped, String(swapped)), SettingsManager.key_name(swapped)]
	refresh()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", _row_size())
	label.custom_minimum_size.x = 300
	return label


func _add_row(row: Dictionary) -> void:
	var key: StringName = row.key
	if row.get("names") is String:
		row = row.duplicate()
		row.names = call(row.names)
		row.max = float(row.names.size() - 1)
	var label := _label(row.label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override(&"font_size", _row_size())
	value_label.custom_minimum_size.x = 150
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_labels[key] = value_label
	var control: Control
	if row.has("min"):
		var slider := HSlider.new()
		slider.min_value = row.min
		slider.max_value = row.max
		slider.step = row.step
		slider.custom_minimum_size = Vector2(260, 26)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(value: float) -> void:
			SettingsManager.set(key, int(value) if SettingsManager.get(key) is int else value)
			_update_value_label(row))
		control = slider
	else:
		var check := CheckButton.new()
		check.toggled.connect(func(on: bool) -> void:
			SettingsManager.set(key, on)
			_update_value_label(row))
		control = check
	controls[key] = control
	_rows_by_key[key] = row
	_append(row.tab, [label, control, value_label])


func _add_button_row(row: Dictionary) -> void:
	var label := _label(row.label)
	var button := Button.new()
	button.text = row.text
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override(&"font_size", _row_size())
	var id: StringName = row.button
	button.pressed.connect(func() -> void:
		if id == &"calibrate":
			open_calibration()
		elif id == &"reset_controls":
			SettingsManager.reset_bindings()
			_note.text = "Keys and pad back to defaults."
			refresh())
	controls[id] = button
	_append(row.tab, [label, button, Control.new()])


func _add_rebind_row(action: StringName) -> void:
	var label := _label(ACTION_NAMES.get(action, String(action)))
	var button := Button.new()
	button.custom_minimum_size = Vector2(160, 0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override(&"font_size", _row_size())
	button.text = SettingsManager.key_name(action)
	button.pressed.connect(func() -> void:
		_waiting_action = action
		button.text = "PRESS A KEY")
	controls[action] = button
	_append(Tab.CONTROLS, [label, button, Control.new()])


func _append(tab: int, nodes: Array) -> void:
	for node: Control in nodes:
		_rows.add_child(node)
	_row_nodes.append([tab, nodes])


func _update_value_label(row: Dictionary) -> void:
	var value: Variant = SettingsManager.get(row.key)
	var text: String
	if value is bool:
		text = "ON" if value else "OFF"
	elif row.has("names"):
		text = row.names[clampi(int(value), 0, row.names.size() - 1)]
	elif row.get("percent", false):
		text = "%d%%" % roundi(value * 100.0)
	else:
		text = row.fmt % value
	(_value_labels[row.key] as Label).text = text


func resolution_names() -> Array:
	var out := []
	for size in SettingsManager.RESOLUTIONS:
		out.append("%dx%d" % [size.x, size.y])
	return out


## On the CRT (inside the main menu's SubViewport) text needs to be bigger.
func _row_size() -> int:
	return ROW_FONT_SIZE_CRT if get_viewport() is SubViewport else ROW_FONT_SIZE
