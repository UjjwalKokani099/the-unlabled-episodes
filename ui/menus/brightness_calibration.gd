class_name BrightnessCalibration
extends Control
## Brightness calibration (Settings > Display > CALIBRATE): three dark marks on black, and
## the brightness slider. The player raises brightness until the left mark is barely
## visible, the usual horror-game calibration. Esc (via SettingsMenu.close) or DONE ends it.

signal finished

## Mark greys: barely visible / visible / clearly visible at the right brightness.
const MARKS := [0.03, 0.07, 0.15]

var font_size: int = 24
var slider: HSlider
var _value: Label
var _done: Button


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 22)
	center.add_child(box)
	var title := Label.new()
	title.text = "BRIGHTNESS"
	title.add_theme_font_size_override(&"font_size", font_size + 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var marks := HBoxContainer.new()
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override(&"separation", 48)
	for grey: float in MARKS:
		var mark := ColorRect.new()
		mark.color = Color(grey, grey, grey)
		mark.custom_minimum_size = Vector2(110, 110)
		marks.add_child(mark)
	box.add_child(marks)
	var hint := Label.new()
	hint.text = "Adjust until the left mark is barely visible."
	hint.add_theme_font_size_override(&"font_size", font_size)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	slider = HSlider.new()
	slider.min_value = 0.6
	slider.max_value = 1.6
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(360, 26)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		SettingsManager.brightness = value
		_value.text = "%.2f" % value)
	row.add_child(slider)
	_value = Label.new()
	_value.add_theme_font_size_override(&"font_size", font_size)
	_value.custom_minimum_size.x = 80
	row.add_child(_value)
	box.add_child(row)
	_done = Button.new()
	_done.text = "DONE"
	_done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done.add_theme_font_size_override(&"font_size", font_size)
	_done.pressed.connect(finish)
	box.add_child(_done)


func open() -> void:
	slider.set_value_no_signal(SettingsManager.brightness)
	_value.text = "%.2f" % SettingsManager.brightness
	visible = true
	slider.grab_focus()


func finish() -> void:
	if not visible:
		return
	visible = false
	finished.emit()
