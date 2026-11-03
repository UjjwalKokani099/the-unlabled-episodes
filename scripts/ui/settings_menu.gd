class_name SettingsMenu
extends Control
## Settings screen (main menu + pause menu) with tabs: Graphics, Audio, Controls, Subtitles.
## Rows come from ROWS (one line per setting) plus one rebind row per Settings.REBINDABLE
## action. Every change goes straight into the Settings store, which saves.
## Hosts call open(), and close() on Esc; `closed` fires either way.

signal closed

const TABS := ["GRAPHICS", "AUDIO", "CONTROLS", "SUBTITLES"]
## Sliders need min/max/step; "percent" shows 0..1 as 0..100%; "names" labels int steps.
const ROWS: Array[Dictionary] = [
	{"tab": 0, "key": &"graphics_quality", "label": "Quality preset", "min": 0.0, "max": 2.0, "step": 1.0, "names": ["LOW", "MEDIUM", "HIGH"]},
	{"tab": 0, "key": &"brightness", "label": "Brightness", "min": 0.6, "max": 1.6, "step": 0.05, "fmt": "%.2f"},
	{"tab": 0, "key": &"film_look", "label": "Film look", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": 0, "key": &"screen_effects", "label": "VHS effect", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": 0, "key": &"ps1_mode", "label": "PS1 mode"},
	{"tab": 0, "key": &"fov", "label": "Field of view", "min": 60.0, "max": 100.0, "step": 1.0, "fmt": "%d"},
	{"tab": 0, "key": &"head_bob", "label": "Head bob + sway"},
	{"tab": 0, "key": &"fullscreen", "label": "Fullscreen"},
	{"tab": 0, "key": &"show_fps", "label": "Show FPS"},
	{"tab": 1, "key": &"master_volume", "label": "Master volume", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": 1, "key": &"music_volume", "label": "Music", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": 1, "key": &"sfx_volume", "label": "Sound effects", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": 1, "key": &"ambience_volume", "label": "Ambience", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"tab": 2, "key": &"mouse_sensitivity", "label": "Mouse sensitivity", "min": 0.02, "max": 0.6, "step": 0.01, "fmt": "%.2f"},
	{"tab": 2, "key": &"invert_y", "label": "Invert mouse Y"},
	{"tab": 2, "key": &"crouch_toggle", "label": "Toggle crouch"},
	{"tab": 3, "key": &"subtitles", "label": "Subtitles"},
	{"tab": 3, "key": &"subtitle_size", "label": "Subtitle size", "min": 0.0, "max": 2.0, "step": 1.0, "names": ["SMALL", "MEDIUM", "LARGE"]},
]
const ACTION_NAMES := {&"move_forward": "Move forward", &"move_back": "Move back", &"move_left": "Move left",
	&"move_right": "Move right", &"sprint": "Sprint", &"crouch": "Crouch", &"flashlight": "Flashlight",
	&"interact": "Use / interact", &"spot": "Pause tape (spot him)", &"night_vision": "Night vision", &"objectives": "Show objectives"}
const ROW_FONT_SIZE := 20

## Setting key (or action name for rebind rows) -> its control, for refresh and tests.
var controls: Dictionary = {}
var current_tab: int = 0
var _value_labels: Dictionary = {}
var _row_nodes: Array = []  # [tab, [nodes]]
var _waiting_action: StringName = &""
var _tabs: TabBar

@onready var _rows: GridContainer = $Panel/VBox/Rows
@onready var _back: Button = $Panel/VBox/BackList/Back


func _ready() -> void:
	visible = false
	_tabs = TabBar.new()
	for t in TABS:
		_tabs.add_tab(t)
	_tabs.tab_changed.connect(show_tab)
	$Panel/VBox.add_child(_tabs)
	$Panel/VBox.move_child(_tabs, 1)
	for row in ROWS:
		_add_row(row)
	for action in Settings.REBINDABLE:
		_add_rebind_row(action)
	_back.pressed.connect(close)
	show_tab(0)


func open() -> void:
	refresh()
	visible = true
	show_tab(current_tab)


func close() -> void:
	if not visible:
		return
	_waiting_action = &""
	visible = false
	closed.emit()


## True while a rebind row waits for the new key (Esc then cancels the rebind only).
func is_waiting_for_key() -> bool:
	return _waiting_action != &""


func show_tab(index: int) -> void:
	current_tab = index
	_tabs.set_current_tab(index)
	var first: Control = null
	for entry in _row_nodes:
		for node: Control in entry[1]:
			node.visible = entry[0] == index
			if entry[0] == index and first == null and (node is Range or node is BaseButton):
				first = node
	if first and visible:
		first.grab_focus()


func refresh() -> void:
	for row in ROWS:
		var control: Control = controls[row.key]
		if control is HSlider:
			(control as HSlider).set_value_no_signal(Settings.get(row.key))
		else:
			(control as CheckButton).set_pressed_no_signal(Settings.get(row.key))
		_update_value_label(row)
	for action in Settings.REBINDABLE:
		(controls[action] as Button).text = Settings.key_name(action)


func _input(event: InputEvent) -> void:
	if _waiting_action == &"" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	var action := _waiting_action
	_waiting_action = &""
	if key.physical_keycode != KEY_ESCAPE:
		Settings.rebind(action, key.physical_keycode)
	(controls[action] as Button).text = Settings.key_name(action)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	label.custom_minimum_size.x = 260
	return label


func _add_row(row: Dictionary) -> void:
	var key: StringName = row.key
	var label := _label(row.label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	value_label.custom_minimum_size.x = 110
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_labels[key] = value_label
	var control: Control
	if row.has("min"):
		var slider := HSlider.new()
		slider.min_value = row.min
		slider.max_value = row.max
		slider.step = row.step
		slider.custom_minimum_size = Vector2(300, 26)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(value: float) -> void:
			Settings.set(key, int(value) if Settings.get(key) is int else value)
			_update_value_label(row))
		control = slider
	else:
		var check := CheckButton.new()
		check.toggled.connect(func(on: bool) -> void:
			Settings.set(key, on)
			_update_value_label(row))
		control = check
	controls[key] = control
	for node in [label, control, value_label]:
		_rows.add_child(node)
	_row_nodes.append([row.tab, [label, control, value_label]])


func _add_rebind_row(action: StringName) -> void:
	var label := _label(ACTION_NAMES.get(action, String(action)))
	var button := Button.new()
	button.custom_minimum_size = Vector2(160, 0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	button.text = Settings.key_name(action)
	button.pressed.connect(func() -> void:
		_waiting_action = action
		button.text = "PRESS A KEY")
	controls[action] = button
	var spacer := Control.new()
	for node in [label, button, spacer]:
		_rows.add_child(node)
	_row_nodes.append([2, [label, button, spacer]])


func _update_value_label(row: Dictionary) -> void:
	var value: Variant = Settings.get(row.key)
	var text: String
	if value is bool:
		text = "ON" if value else "OFF"
	elif row.has("names"):
		text = row.names[int(value)]
	elif row.get("percent", false):
		text = "%d%%" % roundi(value * 100.0)
	else:
		text = row.fmt % value
	(_value_labels[row.key] as Label).text = text
