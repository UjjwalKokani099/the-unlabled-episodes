class_name ObjectivePanel
extends VBoxContainer
## Top-left list of current objectives (studio spec: short, plain language, soft fade, a
## subtle sound on updates, optional). Appears for a few seconds whenever objectives change
## (unless Settings > Gameplay > Show objectives is off) and while the "objectives" key (Tab)
## is held. New lines slide in; finished ones tick off, then fade. No sound while a checkpoint
## rebuilds the objectives (EventBus.replaying).

const SHOW_SECONDS := 5.0
const DONE_LINGER_SECONDS := 2.5
const ACTIVE_COLOR := Color(0.94, 0.94, 0.92)
const DONE_COLOR := Color(0.62, 0.8, 0.6)
const FONT: Font = preload("res://assets/fonts/ui.tres")
const FONT_SIZE := 22

var _show_left: float = 0.0
var _recently_done: Array[ObjectiveData] = []
var _done_left: Dictionary = {}  # ObjectiveData -> seconds left
var _shown_ids: Dictionary = {}  # objective id -> true once its line has slid in


func _ready() -> void:
	modulate.a = 0.0
	ObjectiveManager.started.connect(func(o: ObjectiveData) -> void: _on_changed(true))
	ObjectiveManager.progressed.connect(func(_o: ObjectiveData, _n: int) -> void: _on_changed(true))
	ObjectiveManager.completed.connect(_on_completed)
	_rebuild()


func _process(delta: float) -> void:
	_show_left = maxf(_show_left - delta, 0.0)
	var expired := false
	for objective in _recently_done.duplicate():
		_done_left[objective] -= delta
		if _done_left[objective] <= 0.0:
			_recently_done.erase(objective)
			_done_left.erase(objective)
			expired = true
	if expired:
		_rebuild()
	var auto_show := _show_left > 0.0 and SettingsManager.show_objectives
	var want_visible := auto_show or Input.is_action_pressed(&"objectives")
	var target_alpha := 1.0 if want_visible and get_child_count() > 0 else 0.0
	modulate.a = move_toward(modulate.a, target_alpha, delta * 3.0)


## The visible lines (tests).
func line_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for child in get_children():
		out.append((child as Label).text)
	return out


func _on_changed(sound: bool = true) -> void:
	_show_left = SHOW_SECONDS
	_rebuild()
	if sound and not EventBus.replaying and SettingsManager.show_objectives:
		AudioManager.play_ui(&"objective")


func _on_completed(objective: ObjectiveData) -> void:
	if EventBus.replaying:  # restored from a checkpoint, not newly done
		_rebuild()
		return
	_recently_done.append(objective)
	_done_left[objective] = DONE_LINGER_SECONDS
	_on_changed(true)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for objective in _recently_done:
		_add_line("✓  " + objective.text, DONE_COLOR, false)
	for objective in ObjectiveManager.get_active():
		var text := "•  " + objective.text
		if objective.required > 1:
			text += "  %d/%d" % [ObjectiveManager.get_progress(objective.id), objective.required]
		var fresh := not _shown_ids.has(objective.id)
		_shown_ids[objective.id] = true
		_add_line(text, ACTIVE_COLOR, fresh and not EventBus.replaying)


func _add_line(text: String, color: Color, slide_in: bool) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override(&"outline_size", 3)
	add_child(label)
	if slide_in:
		label.modulate.a = 0.0
		var tween := label.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 1.0, 0.45)
		label.position.x = -14.0
		tween.tween_property(label, "position:x", 0.0, 0.45)
