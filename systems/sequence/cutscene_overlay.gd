class_name CutsceneOverlay
extends CanvasLayer
## Cutscene chrome, owned by a SequencePlayer: letterbox bars that slide in and out (only
## where a moment wants them) and the hold-to-skip ring ("Hold [E] to skip"), which fills
## while E / A is held and appears only once the player starts holding.

const BAR := 0.11  # bar height, fraction of the screen

var skip_progress: float = 0.0
var _top: ColorRect
var _bottom: ColorRect
var _ring: Control
var _label: Label
var _skip_enabled: bool = false
var _letterbox_tween: Tween


func _ready() -> void:
	layer = 15  # above the camcorder look, under the HUD's subtitles
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		if i == 0:
			_top = bar
		else:
			_bottom = bar
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_label = Label.new()
	_label.add_theme_font_override(&"font", load("res://assets/fonts/vcr.tres"))
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.8))
	add_child(_label)
	_layout(0.0)
	_ring.visible = false
	_label.visible = false


## Bars in (on) or out over `seconds`.
func letterbox(on: bool, seconds: float) -> void:
	if _letterbox_tween:
		_letterbox_tween.kill()
	var target := 1.0 if on else 0.0
	if seconds <= 0.0:
		_layout(target)
		return
	var from := _top.size.y / maxf(_screen().y * BAR, 1.0)
	_letterbox_tween = create_tween()
	_letterbox_tween.tween_method(_layout, from, target, seconds).set_trans(Tween.TRANS_SINE)


func is_letterboxed() -> bool:
	return _top.size.y > 1.0


func show_skip(on: bool) -> void:
	_skip_enabled = on
	if not on:
		set_skip_progress(0.0)


func set_skip_progress(value: float) -> void:
	skip_progress = clampf(value, 0.0, 1.0)
	var show := _skip_enabled and skip_progress > 0.0
	_ring.visible = show
	_label.visible = show
	if show:
		_label.text = "HOLD [%s] TO SKIP" % SettingsManager.key_name(&"interact")
		_ring.queue_redraw()


func _layout(amount: float) -> void:
	var s := _screen()
	var h := s.y * BAR * amount
	_top.position = Vector2.ZERO
	_top.size = Vector2(s.x, h)
	_bottom.position = Vector2(0, s.y - h)
	_bottom.size = Vector2(s.x, h)
	_ring.position = Vector2(s.x - 96, s.y - 96)
	_ring.size = Vector2(56, 56)
	_label.position = Vector2(s.x - 360, s.y - 82)
	_label.size = Vector2(250, 30)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _draw_ring() -> void:
	var c := _ring.size * 0.5
	_ring.draw_arc(c, 22.0, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 4.0, true)
	_ring.draw_arc(c, 22.0, -PI / 2, -PI / 2 + TAU * skip_progress, 48, Color(1, 1, 1, 0.9), 4.0, true)


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
