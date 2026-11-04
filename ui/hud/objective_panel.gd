class_name ObjectivePanel
extends VBoxContainer
## Top-right list of current objectives. Appears for a few seconds whenever objectives
## change (unless Settings > Gameplay > Show objectives is off), and while the "objectives"
## key (Tab) is held. Completed lines linger briefly.

const SHOW_SECONDS := 5.0
const DONE_LINGER_SECONDS := 2.5
const ACTIVE_COLOR := Color(0.92, 0.92, 0.92)
const DONE_COLOR := Color(0.55, 0.8, 0.55)

var _show_left: float = 0.0
var _recently_done: Array[ObjectiveData] = []
var _done_left: Dictionary = {}  # ObjectiveData -> seconds left


func _ready() -> void:
	modulate.a = 0.0
	ObjectiveManager.started.connect(_on_changed.unbind(1))
	ObjectiveManager.progressed.connect(_on_changed.unbind(2))
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


func _on_changed() -> void:
	_show_left = SHOW_SECONDS
	_rebuild()


func _on_completed(objective: ObjectiveData) -> void:
	if EventBus.replaying:  # restored from a checkpoint, not newly done
		_rebuild()
		return
	_recently_done.append(objective)
	_done_left[objective] = DONE_LINGER_SECONDS
	_on_changed()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for objective in _recently_done:
		_add_line(objective.text + "  - done", DONE_COLOR)
	for objective in ObjectiveManager.get_active():
		var text := objective.text
		if objective.required > 1:
			text += "  %d/%d" % [ObjectiveManager.get_progress(objective.id), objective.required]
		_add_line(text, ACTIVE_COLOR)


func _add_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	label.add_theme_font_size_override(&"font_size", 18)
	add_child(label)
