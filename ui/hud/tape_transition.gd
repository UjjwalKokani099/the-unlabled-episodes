class_name TapeTransition
extends CanvasLayer
## Full-screen black card used between levels, styled like a VCR screen:
##   "PLAY ►" top-left, tape title in the middle, and on titled cards (the loading screen)
##   turning cassette reels + "LOADING nn%" bottom-right and an in-world tip at the bottom.
## Built in code; owned by the SceneLoader autoload. Keeps running while the game is paused.

const FADE_OUT := 0.45
const FADE_IN := 0.6

var _black: ColorRect
var _header: Label
var _body: Label
var _tip: Label
var _loading: Label
var _reels: ReelIndicator
var _blink: float = 0.0


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var font: Font = load("res://assets/fonts/vcr.tres")

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

	_tip = _make_label(load("res://assets/fonts/ui.tres"), 22, HORIZONTAL_ALIGNMENT_CENTER)
	_tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tip.offset_top = -150.0
	_tip.offset_bottom = -96.0
	_tip.offset_left = 160.0
	_tip.offset_right = -160.0
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.62))
	_black.add_child(_tip)

	var corner := HBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_left = -330.0
	corner.offset_top = -86.0
	corner.offset_right = -56.0
	corner.offset_bottom = -36.0
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading = _make_label(font, 26, HORIZONTAL_ALIGNMENT_RIGHT)
	_loading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corner.add_child(_loading)
	_reels = ReelIndicator.new()
	corner.add_child(_reels)
	_black.add_child(corner)
	_set_text_visible(false)
	set_progress(0.0)


func _process(delta: float) -> void:
	if _loading.visible:
		_blink = fmod(_blink + delta, 1.0)
		_loading.text = ("FF >> " if _blink < 0.6 else "      ") + "LOADING %d%%" % roundi(_reels.progress * 100.0)


## Loading progress 0..1 (SceneLoader feeds the threaded load's progress).
func set_progress(value: float) -> void:
	_reels.progress = value


## The tip on the card ("" = none).
func tip_text() -> String:
	return _tip.text


func is_covering() -> bool:
	return _black.modulate.a > 0.0


## Fade to black, then show the text. Await it.
func cover(header: String, lines: PackedStringArray, tip: String = "") -> void:
	_header.text = header
	_body.text = "\n".join(lines)
	_tip.text = tip
	set_progress(0.0)
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
	# The loading indicator + tip belong to titled cards; a plain fade stays plain.
	var titled := value and _body.text != ""
	_tip.visible = titled
	_loading.visible = titled
	_reels.visible = titled


func _make_label(font: Font, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.9))
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
