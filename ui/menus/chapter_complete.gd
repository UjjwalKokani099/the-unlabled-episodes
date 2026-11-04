class_name ChapterComplete
extends CanvasLayer
## End of a tape (studio spec 9: "a dark fade and a lingering sound before the Chapter
## Complete screen"). The picture fades to black while the tape runs out (hiss thinning, the
## deck's stop clunk), then the VCR card: tape title, END OF TAPE, runtime and sightings,
## PRESS ANY KEY. Any key (after a short guard) or `auto_continue` seconds -> `closed`.
## GameManager.complete_chapter() shows it and then loads the room.

signal closed

const RUNOUT := preload("res://assets/audio/sfx/tape_runout.wav")
const FADE := 1.6
const GUARD := 1.2

var chapter: ChapterData
var runtime: float = 0.0
var auto_continue: float = 20.0
var _black: ColorRect
var _card: Control
var _prompt: Label
var _shown_for: float = -1.0
var _done: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = _build_card()
	_card.modulate.a = 0.0
	add_child(_card)
	AudioManager.play_sfx(RUNOUT, -6.0)
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 1.0, FADE).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(minf(2.6, auto_continue * 0.3))
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func() -> void: _shown_for = 0.0)


func is_showing_card() -> bool:
	return _shown_for >= 0.0


func continue_now() -> void:
	if _done:
		return
	_done = true
	closed.emit()


func _process(delta: float) -> void:
	if _shown_for >= 0.0:
		_shown_for += delta
		_prompt.modulate.a = 0.35 + 0.65 * absf(sin(_shown_for * 2.2))
	if _shown_for >= auto_continue or (auto_continue < 1.0 and _black.modulate.a >= 1.0):
		continue_now()


func _input(event: InputEvent) -> void:
	if _shown_for < GUARD or event.is_echo():
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton
			or event is InputEventScreenTouch) and event.is_pressed():
		get_viewport().set_input_as_handled()
		continue_now()


func _build_card() -> Control:
	var vcr: Font = load("res://assets/fonts/vcr.tres")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stop := _label("■ STOP", vcr, 28)
	stop.position = Vector2(74, 48)
	root.add_child(stop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	center.add_child(box)
	box.add_child(_label(chapter.title if chapter else "TAPE", vcr, 48, true))
	box.add_child(_label(chapter.subtitle if chapter else "", vcr, 36, true))
	box.add_child(_label("END OF TAPE", vcr, 30, true, Color(1, 1, 1, 0.6)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)
	var secs := roundi(runtime)
	var stats := "RUNTIME %d:%02d:%02d" % [secs / 3600, secs / 60 % 60, secs % 60]
	if chapter and chapter.spots_total > 0:
		stats += "      SIGHTINGS %d/%d" % [GameManager.spotted_count(chapter.spot_prefix), chapter.spots_total]
	box.add_child(_label(stats, vcr, 26, true, Color(0.85, 0.9, 1.0, 0.85)))
	_prompt = _label("PRESS ANY KEY", vcr, 26, true)
	root.add_child(_prompt)
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_left = 0.0
	_prompt.offset_right = 0.0
	_prompt.offset_top = -150.0
	_prompt.offset_bottom = -110.0
	return root


func _label(text: String, font: Font, size: int, centered: bool = false, color: Color = Color(1, 1, 1, 0.92)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
