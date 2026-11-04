class_name CreditsRoll
extends Control
## Credits on the main menu's CRT: data/credits.json (built by tools/gen_credits.py from the
## asset credit files) rolling up slowly, like the end of a tape. Up/down scrolls by hand
## (the roll pauses for a moment), it loops at the end. BACK or Esc leaves.

signal closed

const PATH := "res://data/credits.json"
const SPEED := 38.0  # px/s
const MANUAL_STEP := 60.0
const RESUME_AFTER := 2.5

var scroll: ScrollContainer
var _box: VBoxContainer
var _back: Button
var _offset: float = 0.0
var _hold: float = 0.0
var _built: bool = false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := VBoxContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 70.0
	panel.offset_right = -70.0
	panel.offset_top = 96.0
	panel.offset_bottom = -60.0
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_box)
	var list := MenuList.new()
	_back = Button.new()
	_back.text = "BACK"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.add_theme_font_size_override(&"font_size", 34)
	_back.pressed.connect(close)
	list.add_child(_back)
	panel.add_child(list)


func open() -> void:
	if not _built:
		_build()
	_offset = 0.0
	_hold = 1.0
	scroll.scroll_vertical = 0
	visible = true
	_back.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Number of credit lines shown (tests).
func line_count() -> int:
	return _box.get_child_count()


func _process(delta: float) -> void:
	if not visible:
		return
	if _hold > 0.0:
		_hold -= delta
		return
	_offset += SPEED * delta
	var end := maxf(_box.size.y - scroll.size.y, 0.0)
	if _offset > end + scroll.size.y * 0.5:
		_offset = 0.0
		_hold = 1.5
	scroll.scroll_vertical = int(_offset)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down")):
		_manual(event)
		get_viewport().set_input_as_handled()


func _manual(event: InputEvent) -> void:
	var step := 0.0
	if event.is_action_pressed(&"ui_up"):
		step = -MANUAL_STEP
	elif event.is_action_pressed(&"ui_down"):
		step = MANUAL_STEP
	if step != 0.0:
		_offset = maxf(_offset + step, 0.0)
		scroll.scroll_vertical = int(_offset)
		_hold = RESUME_AFTER


func _build() -> void:
	_built = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary):
		_add("CREDITS FILE MISSING", 30, Color.WHITE)
		return
	for section: Dictionary in (data as Dictionary).get("sections", []):
		if section.title != "":
			_add(String(section.title).to_upper(), 36, Color(1, 1, 1, 0.95))
		for line: String in section.lines:
			_add(line, 26, Color(0.82, 0.86, 1.0, 0.85))
		_add("", 26, Color.WHITE)


func _add(text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	_box.add_child(label)
