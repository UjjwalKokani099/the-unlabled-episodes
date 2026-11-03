class_name TouchControls
extends CanvasLayer
## On-screen controls for touch play (iPad / web). Part of the HUD; only visible while
## `InputManager.touch_mode` is on and the game is in "playing" mode (no menu, note, dialogue).
## Left side: floating move stick. Right side: drag to look. Buttons send the same input
## actions as the keyboard, so gameplay code doesn't know the difference.
## RUN and DUCK are toggles (thumbs are busy); RUN switches off when the stick is let go.

const LOOK_SCALE := 0.8  # x SettingsManager.mouse_sensitivity per pixel of drag
const STICK_ZONE := 0.42  # left part of the screen that starts the move stick
const DEAD_ZONE := 0.15

## name -> {action, label, pos (fractions of the screen height, from the bottom-right; from the
## bottom-left with "left": true), radius, mode}
## mode: "hold" (pressed while the finger is down) or "toggle".
const BUTTONS := {
	&"use": {"action": &"interact", "label": "USE", "pos": Vector2(0.085, 0.17), "r": 78.0, "mode": "hold"},
	&"run": {"action": &"sprint", "label": "RUN", "pos": Vector2(0.20, 0.10), "r": 54.0, "mode": "toggle"},
	&"duck": {"action": &"crouch", "label": "DUCK", "pos": Vector2(0.075, 0.38), "r": 54.0, "mode": "toggle"},
	&"light": {"action": &"flashlight", "label": "LIGHT", "pos": Vector2(0.20, 0.30), "r": 48.0, "mode": "hold"},
	&"nv": {"action": &"night_vision", "label": "NV", "pos": Vector2(0.17, 0.50), "r": 44.0, "mode": "hold"},
	&"spot": {"action": &"spot", "label": "II REC", "pos": Vector2(0.075, 0.58), "r": 50.0, "mode": "hold"},
	# top-left corner (the objective list is top-right)
	&"pause": {"action": &"pause", "label": "MENU", "pos": Vector2(0.06, 0.90), "r": 40.0, "mode": "hold", "left": true},
	&"tasks": {"action": &"objectives", "label": "TASKS", "pos": Vector2(0.17, 0.90), "r": 40.0, "mode": "hold", "left": true},
}

var _canvas: Control
var _font: Font
var _stick_finger: int = -1
var _stick_origin: Vector2
var _stick_pos: Vector2
var _look_finger: int = -1
var _button_fingers: Dictionary = {}  # finger index -> button name
var _toggled: Dictionary = {}  # button name -> bool
var _shown: bool = false


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS  # the Spot button pauses the tree
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	var theme := load("res://ui/themes/vcr_theme.tres") as Theme
	_font = theme.default_font if theme and theme.default_font else ThemeDB.fallback_font
	visible = false


func _process(_delta: float) -> void:
	var want := InputManager.touch_mode and InputManager.mouse_captured() \
			and get_tree().get_first_node_in_group("player") != null
	if want != _shown:
		_shown = want
		visible = want
		if not want:
			_release_all()
	if _shown:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		InputManager.note_touch(event)  # we consume touches: Settings wouldn't see them otherwise
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_stick_pos = d.position
			_apply_stick()
		elif d.index == _look_finger:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				player.look(d.relative * LOOK_SCALE)
		get_viewport().set_input_as_handled()


func _touch_down(finger: int, pos: Vector2) -> void:
	var hit := _button_at(pos)
	if hit != &"":
		_button_fingers[finger] = hit
		var b: Dictionary = BUTTONS[hit]
		if hit == &"duck" and SettingsManager.crouch_toggle:
			_send(b.action, true)  # the player toggles crouch itself: just tap the key
			_send(b.action, false)
			_button_fingers.erase(finger)
		elif b.mode == "toggle":
			_set_toggle(hit, not _toggled.get(hit, false))
		else:
			_send(b.action, true)
	elif pos.x < _size().x * STICK_ZONE and _stick_finger == -1:
		_stick_finger = finger
		_stick_origin = pos
		_stick_pos = pos
	elif _look_finger == -1:
		_look_finger = finger


func _touch_up(finger: int) -> void:
	if _button_fingers.has(finger):
		var name: StringName = _button_fingers[finger]
		_button_fingers.erase(finger)
		if BUTTONS[name].mode == "hold":
			_send(BUTTONS[name].action, false)
	elif finger == _stick_finger:
		_stick_finger = -1
		_stick_pos = _stick_origin
		_apply_stick()
		_set_toggle(&"run", false)
	elif finger == _look_finger:
		_look_finger = -1


func _apply_stick() -> void:
	var radius := 90.0 * _scale()
	var v := (_stick_pos - _stick_origin) / radius
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < DEAD_ZONE:
		v = Vector2.ZERO
	_axis(&"move_left", &"move_right", v.x)
	_axis(&"move_forward", &"move_back", v.y)


func _axis(negative: StringName, positive: StringName, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _set_toggle(name: StringName, on: bool) -> void:
	if _toggled.get(name, false) == on:
		return
	_toggled[name] = on
	_send(BUTTONS[name].action, on)


## Sends an action exactly like a key press, so `_unhandled_input` handlers see it too.
func _send(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for finger in _button_fingers:
		var name: StringName = _button_fingers[finger]
		if BUTTONS[name].mode == "hold":
			_send(BUTTONS[name].action, false)
	_button_fingers.clear()
	for name in _toggled.keys():
		_set_toggle(name, false)
	_stick_finger = -1
	_look_finger = -1
	for a in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _button_at(pos: Vector2) -> StringName:
	for name: StringName in BUTTONS:
		var b: Dictionary = BUTTONS[name]
		if pos.distance_to(_button_center(b)) <= b.r * _scale() * 1.15:
			return name
	return &""


func _button_center(b: Dictionary) -> Vector2:
	var s := _size()
	var x: float = b.pos.x * s.y * 1.6
	return Vector2(x if b.get("left", false) else s.x - x, s.y - b.pos.y * s.y)


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _scale() -> float:
	return _size().y / 1080.0


func _draw_controls() -> void:
	var k := _scale()
	var line := Color(1, 1, 1, 0.45)
	var fill := Color(1, 1, 1, 0.22)
	var held := {}
	for f in _button_fingers:
		held[_button_fingers[f]] = true
	for name: StringName in BUTTONS:
		var b: Dictionary = BUTTONS[name]
		var c := _button_center(b)
		var r: float = b.r * k
		if held.has(name) or _toggled.get(name, false):
			_canvas.draw_circle(c, r, fill)
		_canvas.draw_arc(c, r, 0.0, TAU, 48, line, 2.5 * k, true)
		var size := int(22 * k) if b.r > 45.0 else int(18 * k)
		var w := _font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		_canvas.draw_string(_font, c + Vector2(-w * 0.5, size * 0.35), b.label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(1, 1, 1, 0.8))
	if _stick_finger != -1:
		var radius := 90.0 * k
		_canvas.draw_arc(_stick_origin, radius, 0.0, TAU, 48, line, 2.5 * k, true)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(radius)
		_canvas.draw_circle(knob, 34.0 * k, fill)
	else:
		var hint := Vector2(_size().x * 0.14, _size().y * 0.78)
		_canvas.draw_arc(hint, 70.0 * k, 0.0, TAU, 40, Color(1, 1, 1, 0.15), 2.0 * k, true)
