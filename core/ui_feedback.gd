extends Node
## Feedback for every menu control, registered as the autoload "UIFeedback": no button is
## silent or static. Any BaseButton or Slider that enters the tree (in-world menus and the
## CRT menu's SubViewport included) gets:
## - hover / keyboard-or-controller focus: a soft blip + an eased swell (0.12 s);
## - press: a click + a quick press pulse; slider steps tick (throttled).
## Controls in the group "no_ui_feedback" (touch controls) are left alone.

const SWELL := 1.04
const SWELL_TIME := 0.12
const PRESS_TIME := 0.15
const TICK_GAP_MS := 70

var _last_tick_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if not (node is BaseButton or node is Slider):
		return
	var control := node as Control
	if control.is_in_group(&"no_ui_feedback"):
		return
	control.mouse_entered.connect(_on_hover.bind(control))
	control.focus_entered.connect(_on_hover.bind(control))
	control.mouse_exited.connect(_on_leave.bind(control))
	control.focus_exited.connect(_on_leave.bind(control))
	if control is BaseButton:
		(control as BaseButton).pressed.connect(_on_press.bind(control))
	else:
		(control as Slider).value_changed.connect(func(_v: float) -> void: _tick())


func _on_hover(control: Control) -> void:
	if not control.is_visible_in_tree() or (control is BaseButton and (control as BaseButton).disabled):
		return
	AudioManager.play_ui(&"hover")
	if control is BaseButton:
		_tween_scale(control, SWELL, SWELL_TIME)


func _on_leave(control: Control) -> void:
	if control.has_focus() or not is_instance_valid(control):
		return
	_tween_scale(control, 1.0, SWELL_TIME)


func _on_press(control: Control) -> void:
	AudioManager.play_ui(&"click")
	control.pivot_offset = control.size * 0.5
	var t := control.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(control, "scale", Vector2.ONE * 0.96, PRESS_TIME * 0.35)
	t.tween_property(control, "scale", Vector2.ONE * (SWELL if control.has_focus() else 1.0), PRESS_TIME * 0.65)


func _tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick_ms < TICK_GAP_MS:
		return
	_last_tick_ms = now
	AudioManager.play_ui(&"hover")


func _tween_scale(control: Control, to: float, seconds: float) -> void:
	control.pivot_offset = control.size * 0.5
	var t := control.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(control, "scale", Vector2.ONE * to, seconds)
