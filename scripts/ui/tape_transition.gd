class_name TapeTransition
extends CanvasLayer
## Full-screen black card used between levels, styled like a VCR screen:
##   "PLAY ►" top-left, tape title in the middle.
## Built in code; owned by the Game autoload. Keeps running while the game is paused.

const FADE_OUT := 0.45
const FADE_IN := 0.6

var _black: ColorRect
var _header: Label
var _body: Label


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["VCR OSD Mono", "Consolas", "Lucida Console", "Courier New", "Monospace"])
	font.font_weight = 600

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_black)

	_header = _make_label(font, 28, HORIZONTAL_ALIGNMENT_LEFT)
	_header.position = Vector2(74, 48)
	_black.add_child(_header)

	_body = _make_label(font, 44, HORIZONTAL_ALIGNMENT_CENTER)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_black.add_child(_body)
	_set_text_visible(false)


func is_covering() -> bool:
	return _black.modulate.a > 0.0


## Fade to black, then show the text. Await it.
func cover(header: String, lines: PackedStringArray) -> void:
	_header.text = header
	_body.text = "\n".join(lines)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 1.0, FADE_OUT)
	await tween.finished
	_set_text_visible(true)


## Hide the text, then fade back to the game. Await it.
func reveal() -> void:
	_set_text_visible(false)
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 0.0, FADE_IN)
	await tween.finished
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_text_visible(value: bool) -> void:
	_header.visible = value
	_body.visible = value


func _make_label(font: Font, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.9))
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
