class_name SaveIndicator
extends Control
## The save icon (studio spec: "a small save icon in the corner for 2 s"): a turning tape reel
## and "SAVING" in the VCR font, bottom right above the camcorder clock. Shows whenever a
## checkpoint is written (EventBus.checkpoint_saved). Built in code by the HUD.

const SHOW_SECONDS := 2.0
const FADE := 0.25

var _reel: ReelIndicator
var _label: Label
var _left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -250.0
	offset_right = -60.0
	offset_top = -150.0
	offset_bottom = -104.0
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.text = "SAVING"
	_label.add_theme_font_override(&"font", load("res://assets/fonts/vcr.tres"))
	_label.add_theme_font_size_override(&"font_size", 24)
	_label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.85))
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	_reel = ReelIndicator.new()
	_reel.scale = Vector2(0.6, 0.6)
	_reel.custom_minimum_size = Vector2(56, 40)
	row.add_child(_reel)
	modulate.a = 0.0
	visible = false
	EventBus.checkpoint_saved.connect(func(_id: StringName) -> void: flash())


## Show the icon for SHOW_SECONDS (called on every checkpoint save).
func flash() -> void:
	_left = SHOW_SECONDS
	visible = true


func is_showing() -> bool:
	return visible and _left > 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	_reel.progress = fmod(_reel.progress + delta * 0.4, 1.0)
	var target := 1.0 if _left > 0.0 else 0.0
	modulate.a = move_toward(modulate.a, target, delta / FADE)
	if _left <= 0.0 and modulate.a <= 0.0:
		visible = false
