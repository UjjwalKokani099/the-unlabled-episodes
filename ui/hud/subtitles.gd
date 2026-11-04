class_name Subtitles
extends CanvasLayer
## Bottom-centre subtitles. Anything can speak:
##     get_tree().call_group("subtitles", "say", "Vendor", "Le jao.", 3.0)
## White text on a soft black box (opacity = SettingsManager.subtitle_bg_opacity), the
## speaker's name in bold, sizes Small / Medium / Large / XL (SettingsManager.subtitle_size).
## SettingsManager.subtitles = false hides the text; a recorded voice line still plays.

const SIZES := [22, 28, 36, 46]
## Widest a subtitle box gets before the text wraps (pixels at 1080p-ish layouts).
const MAX_WIDTH := 1100.0
const FONT: Font = preload("res://assets/fonts/ui.tres")

@onready var _label: RichTextLabel = $Label
var _box: PanelContainer
var _style: StyleBoxFlat
var _tween: Tween


func _ready() -> void:
	add_to_group("subtitles")
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(6)
	_style.content_margin_left = 18.0
	_style.content_margin_right = 18.0
	_style.content_margin_top = 8.0
	_style.content_margin_bottom = 10.0
	_box = PanelContainer.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_stylebox_override(&"panel", _style)
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_bottom = -120.0
	add_child(_box)
	_label.reparent(_box, false)
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override(&"normal_font", FONT)
	_label.add_theme_font_override(&"bold_font", preload("res://assets/fonts/ui_bold.tres"))
	_label.add_theme_color_override(&"default_color", Color(1, 1, 1))
	_label.add_theme_constant_override(&"outline_size", 0)
	_box.modulate.a = 0.0
	_label.modulate.a = 1.0
	SettingsManager.changed.connect(func(key: StringName) -> void:
		if key == &"subtitle_bg_opacity":
			_apply_box())
	_apply_box()


func say(speaker: String, text: String, seconds: float = 3.0, voice_id: String = "") -> void:
	# The voice plays whether or not subtitles are on; the text stays at least as long.
	var voice_len := AudioManager.play_voice(voice_id)
	seconds = maxf(seconds, voice_len + 0.3)
	if not SettingsManager.subtitles:
		return
	var size: int = SIZES[clampi(SettingsManager.subtitle_size, 0, SIZES.size() - 1)]
	_label.add_theme_font_size_override(&"normal_font_size", size)
	_label.add_theme_font_size_override(&"bold_font_size", size)
	var plain := (speaker + ": " + text) if speaker != "" else text
	_label.text = "[center][b][color=#f2e2c0]%s:[/color][/b] %s[/center]" % [speaker, text] if speaker != "" else "[center]%s[/center]" % text
	# Shrink the box around short lines; long ones wrap at MAX_WIDTH.
	var bare := plain
	for tag in ["[i]", "[/i]", "[color=#e4e4e4]", "[/color]"]:
		bare = bare.replace(tag, "")
	var width := minf(FONT.get_string_size(bare, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 8.0, MAX_WIDTH)
	_label.custom_minimum_size = Vector2(width, 0)
	_layout_box.call_deferred(width)
	if _tween:
		_tween.kill()
	_box.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(seconds)
	_tween.tween_property(_box, "modulate:a", 0.0, 0.4)


## Inner monologue: the player character's own thoughts, in italics, no name, a softer white.
func think(text: String, seconds: float = 3.0, voice_id: String = "") -> void:
	say("", "[i][color=#e4e4e4]%s[/color][/i]" % text, seconds, voice_id)


func current_text() -> String:
	return _label.get_parsed_text() if _box.modulate.a > 0.0 else ""


## Centre the box on the text once the label knows its wrapped height.
func _layout_box(width: float) -> void:
	var w := width + _style.content_margin_left + _style.content_margin_right
	var h := _label.get_content_height() + _style.content_margin_top + _style.content_margin_bottom
	_box.offset_left = -w * 0.5
	_box.offset_right = w * 0.5
	_box.offset_top = _box.offset_bottom - h


func _apply_box() -> void:
	_style.bg_color = Color(0, 0, 0, SettingsManager.subtitle_bg_opacity)
