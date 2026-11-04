class_name DialogueView
extends CanvasLayer
## Plays a Dialogue (res://data/dialogue/*.json) at the bottom of the screen: speaker name,
## typewriter text, then the player's choices (a red bar drains on timed choices; lines with
## a `duration` move on by themselves). Lives in the HUD:
##     get_tree().call_group("hud", "start_dialogue", "res://data/dialogue/tape01/iyer.json", "")
## E / Space / click: finish the line, then continue. Choices: click, number keys, or
## arrows + E. The player can't move while talking. Await `finished` (gives the last node).

signal finished(last_node: String)
signal line_shown(node_id: String)

const CHARS_PER_SECOND := 42.0
const BLIP := preload("res://assets/audio/sfx/ui_blip.wav")

var is_open: bool = false
## Tests: show whole lines at once.
var instant: bool = false
var current_id: String = ""
var _dialogue: Dialogue
var _typing: bool = false
var _shown: float = 0.0
var _last_node: String = ""
var _root: Control
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _blip: AudioStreamPlayer
var _blip_count: int = 0
var _auto_left: float = -1.0     # `duration` countdown to the next line
var _timer_left: float = -1.0    # timed-choice countdown
var _timer_total: float = 0.0
var _timer_bar: ProgressBar


func _ready() -> void:
	layer = 22
	_build()
	_root.visible = false


## Starts a conversation. `start` = node id ("" = the file's start node).
func play(path: String, start: String = "") -> void:
	var d := Dialogue.load_file(path)
	if d == null or is_open:
		return
	_dialogue = d
	is_open = true
	_root.visible = true
	GameManager.block_saving(self)  # never save mid-conversation
	_set_player_input(false)
	_show(d.resolve(start if start != "" else d.start))


## Ends the conversation now.
func stop() -> void:
	GameManager.unblock_saving(self)
	if not is_open:
		return
	is_open = false
	_root.visible = false
	_clear_choices()
	_set_player_input(true)
	InputManager.capture_mouse(true)
	finished.emit(_last_node)


## E / click: finish typing, or go on to the next line (when there are no choices).
func advance() -> void:
	if not is_open:
		return
	if _typing:
		_finish_typing()
		return
	if _choices.get_child_count() > 0:
		return
	_go(_dialogue.node(current_id).get("next", ""))


## Picks the available choice number `index` (0-based).
func choose(index: int) -> void:
	if not is_open or _typing:
		return
	var available := _dialogue.choices(current_id)
	if index < 0 or index >= available.size():
		return
	var choice: Dictionary = available[index]
	Dialogue.apply(choice)
	_go(choice.get("next", ""))


## Seconds left on a timed choice (-1 = no timer running).
func time_left() -> float:
	return _timer_left


## Timed choice ran out: take the node's `timeout` choice (default the last one).
func _time_out() -> void:
	_timer_left = -1.0
	_timer_bar.visible = false
	var available := _dialogue.choices(current_id)
	if available.is_empty():
		return
	var index := int(_dialogue.node(current_id).get("timeout", available.size() - 1))
	choose(clampi(index, 0, available.size() - 1))


func choice_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	if is_open:
		for c: Dictionary in _dialogue.choices(current_id):
			texts.append(c.text)
	return texts


func _go(next: String) -> void:
	_clear_choices()
	var id := _dialogue.resolve(next)
	if id == "":
		stop()
	else:
		_show(id)


func _show(id: String) -> void:
	if id == "":
		stop()
		return
	current_id = id
	_last_node = id
	var n := _dialogue.node(id)
	Dialogue.apply(n)
	_speaker.text = n.get("speaker", "")
	_speaker.visible = _speaker.text != ""
	_text.text = n.get("text", "")
	# Voice line id = <file name>/<node id>, e.g. "deshmukh/hello" ->
	# assets/audio/voice/deshmukh/hello.ogg (or "voice" in the node to override). Silent until recorded.
	var voice_id: String = n.get("voice", "%s/%s" % [_dialogue.path.get_file().get_basename(), id])
	if n.has("audio"):
		AudioManager.play_sfx(load(String(n.audio)) as AudioStream, 0.0, &"Voice")
	elif n.get("text", "") != "...":
		AudioManager.play_voice(voice_id)
	_auto_left = -1.0
	_timer_left = -1.0
	_timer_bar.visible = false
	_shown = 0.0
	_typing = not instant and _text.get_total_character_count() > 0
	_text.visible_characters = -1 if not _typing else 0
	_hint.visible = false
	if not _typing:
		_finish_typing()
	line_shown.emit(id)


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	var n := _dialogue.node(current_id)
	var available := _dialogue.choices(current_id)
	if available.is_empty():
		_hint.text = "[E] ..." if n.get("next", "") != "" else "[E] End"
		_hint.visible = true
		if n.has("duration"):
			_auto_left = float(n.duration)
		return
	if n.has("timer"):
		_timer_total = maxf(float(n.timer), 0.5)
		_timer_left = _timer_total
		_timer_bar.value = 1.0
		_timer_bar.visible = true
	for i in available.size():
		var button := Button.new()
		button.text = "%d.  %s" % [i + 1, available[i].text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override(&"font_size", 22)
		button.pressed.connect(choose.bind(i))
		button.mouse_entered.connect(button.grab_focus)
		_choices.add_child(button)
	(_choices.get_child(0) as Button).grab_focus()
	InputManager.capture_mouse(false)


func _clear_choices() -> void:
	_timer_left = -1.0
	if _timer_bar:
		_timer_bar.visible = false
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _process(delta: float) -> void:
	if is_open and _auto_left >= 0.0:
		_auto_left -= delta
		if _auto_left < 0.0:
			advance()
	if is_open and _timer_left >= 0.0:
		_timer_left -= delta
		_timer_bar.value = maxf(_timer_left / _timer_total, 0.0)
		if _timer_left < 0.0:
			_time_out()
	if not _typing:
		return
	_shown += delta * CHARS_PER_SECOND
	var count := int(_shown)
	if count != _text.visible_characters:
		_text.visible_characters = count
		_blip_count += 1
		if _blip_count % 3 == 0:
			_blip.pitch_scale = randf_range(0.85, 1.0)
			_blip.play()
	if count >= _text.get_total_character_count():
		_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9 and _choices.get_child_count() > 0:
			choose(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
	if _choices.get_child_count() > 0:
		return  # buttons handle E (ui_accept), arrows and clicks
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()  # no pausing mid-sentence


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.72)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override(&"panel", style)
	panel.anchor_left = 0.18
	panel.anchor_right = 0.82
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -300
	panel.offset_bottom = -40
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override(&"font_size", 22)
	_speaker.add_theme_color_override(&"font_color", Color(1, 0.82, 0.48))
	box.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override(&"normal_font_size", 26)
	_text.custom_minimum_size = Vector2(0, 40)
	box.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override(&"separation", 2)
	box.add_child(_choices)
	# timed choices: a thin bar that drains (only on nodes with a `timer`)
	_timer_bar = ProgressBar.new()
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 1.0
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.2, 0.15, 0.9)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	_timer_bar.add_theme_stylebox_override(&"fill", fill)
	_timer_bar.add_theme_stylebox_override(&"background", back)
	_timer_bar.visible = false
	box.add_child(_timer_bar)
	_hint = Label.new()
	_hint.add_theme_font_size_override(&"font_size", 16)
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)
	_blip = AudioStreamPlayer.new()
	_blip.stream = BLIP
	_blip.volume_db = -22.0
	_blip.bus = &"SFX"
	add_child(_blip)


func _set_player_input(enabled: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_enabled = enabled
