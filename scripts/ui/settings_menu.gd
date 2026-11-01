class_name SettingsMenu
extends Control
## Settings screen used by the main menu and the pause menu. Rows are generated from ROWS
## (one line per setting); every change goes straight into the Settings store, which saves.
## The host menu calls open(), and close() when Esc is pressed; `closed` fires either way.

signal closed

## key = Settings property. Sliders need min/max/step; "percent" shows 0..1 as 0..100%.
const ROWS: Array[Dictionary] = [
	{"key": &"mouse_sensitivity", "label": "Mouse sensitivity", "min": 0.02, "max": 0.6, "step": 0.01, "fmt": "%.2f"},
	{"key": &"invert_y", "label": "Invert mouse Y"},
	{"key": &"fov", "label": "Field of view", "min": 60.0, "max": 100.0, "step": 1.0, "fmt": "%d"},
	{"key": &"crouch_toggle", "label": "Toggle crouch"},
	{"key": &"head_bob", "label": "Head bob + sway"},
	{"key": &"screen_effects", "label": "VHS effect", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"key": &"graphics_quality", "label": "Graphics", "min": 0.0, "max": 2.0, "step": 1.0, "names": ["LOW", "MEDIUM", "HIGH"]},
	{"key": &"show_fps", "label": "Show FPS"},
	{"key": &"brightness", "label": "Brightness", "min": 0.6, "max": 1.6, "step": 0.05, "fmt": "%.2f"},
	{"key": &"fullscreen", "label": "Fullscreen"},
	{"key": &"master_volume", "label": "Master volume", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"key": &"music_volume", "label": "Music", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"key": &"sfx_volume", "label": "Sound effects", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
	{"key": &"ambience_volume", "label": "Ambience", "min": 0.0, "max": 1.0, "step": 0.05, "percent": true},
]
const ROW_FONT_SIZE := 20

## Setting key -> its control (HSlider or CheckButton), for refresh and tests.
var controls: Dictionary = {}
var _value_labels: Dictionary = {}

@onready var _rows: GridContainer = $Panel/VBox/Rows
@onready var _back_list: MenuList = $Panel/VBox/BackList
@onready var _back: Button = $Panel/VBox/BackList/Back


func _ready() -> void:
	visible = false
	for row in ROWS:
		_add_row(row)
	_back.pressed.connect(close)


func open() -> void:
	refresh()
	visible = true
	(controls[ROWS[0].key] as Control).grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Re-read every value from Settings.
func refresh() -> void:
	for row in ROWS:
		var key: StringName = row.key
		var control: Control = controls[key]
		if control is HSlider:
			(control as HSlider).set_value_no_signal(Settings.get(key))
		else:
			(control as CheckButton).set_pressed_no_signal(Settings.get(key))
		_update_value_label(row)


func _add_row(row: Dictionary) -> void:
	var key: StringName = row.key
	var label := Label.new()
	label.text = row.label
	label.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	label.custom_minimum_size.x = 260
	_rows.add_child(label)

	var value_label := Label.new()
	value_label.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	value_label.custom_minimum_size.x = 90
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_labels[key] = value_label

	if row.has("min"):
		var slider := HSlider.new()
		slider.min_value = row.min
		slider.max_value = row.max
		slider.step = row.step
		slider.custom_minimum_size = Vector2(300, 26)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(value: float) -> void:
			# Whole-number settings (e.g. the graphics preset) must stay ints.
			Settings.set(key, int(value) if Settings.get(key) is int else value)
			_update_value_label(row))
		controls[key] = slider
		_rows.add_child(slider)
	else:
		var check := CheckButton.new()
		check.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
		check.toggled.connect(func(on: bool) -> void:
			Settings.set(key, on)
			_update_value_label(row))
		controls[key] = check
		_rows.add_child(check)
	_rows.add_child(value_label)


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
