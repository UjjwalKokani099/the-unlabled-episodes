extends Node
## Input devices and mouse capture, registered as the autoload "InputManager".
##
## - Which device the player is using right now (keyboard+mouse, gamepad, touch); UI prompts
##   and touch controls follow `device_changed`.
## - Every "grab / free the mouse" goes through capture_mouse(); read mouse_captured(), never
##   Input.mouse_mode. In touch mode the mouse is never captured: mouse_captured() reports
##   what the game asked for, so gameplay code works the same with fingers (iPad web build).
## - Browsers also report finger drags as mouse motion: only a mouse that travels 80+ px with
##   no finger down for a second switches back from touch.

signal device_changed(device: Device)

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

## Stick movement below this is noise, not a device switch.
const STICK_DEADZONE := 0.35
## Gamepad layout (Xbox names; Godot maps PlayStation/Switch pads onto the same indices).
## Added at startup next to the keyboard keys, so rebinding a key never loses the pad.
const PAD_BUTTONS := {
	&"interact": JOY_BUTTON_A, &"crouch": JOY_BUTTON_B, &"flashlight": JOY_BUTTON_X,
	&"night_vision": JOY_BUTTON_Y, &"spot": JOY_BUTTON_LEFT_SHOULDER, &"objectives": JOY_BUTTON_BACK,
	&"sprint": JOY_BUTTON_LEFT_STICK, &"pause": JOY_BUTTON_START,
}
## action -> [axis, direction]. look_* are created here (no keyboard keys).
const PAD_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0], &"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	&"look_left": [JOY_AXIS_RIGHT_X, -1.0], &"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"look_up": [JOY_AXIS_RIGHT_Y, -1.0], &"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	&"interact": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}
## Right stick fully over = this many degrees per second (x controller_sensitivity).
const PAD_LOOK_SPEED := 150.0

var device: Device = Device.KEYBOARD_MOUSE
## True after the first screen touch, false again once a real mouse moves. Not saved.
var touch_mode: bool:
	get:
		return device == Device.TOUCH

var _want_capture: bool = false
var _fingers: Dictionary = {}  # touch index -> true while that finger is down
var _last_touch_ms: int = -100000
var _mouse_travel: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_gamepad_map()


## Right stick as a look vector (x right, y down), dead zone applied.
func pad_look() -> Vector2:
	return Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.15)


## Adds the pad buttons/sticks to the input map (again after InputMap reloads).
func add_gamepad_map() -> void:
	for action: StringName in PAD_BUTTONS:
		if not InputMap.has_action(action):
			continue
		var button := InputEventJoypadButton.new()
		button.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, button)
	for action: StringName in PAD_AXES:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var motion := InputEventJoypadMotion.new()
		motion.axis = PAD_AXES[action][0]
		motion.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, motion)


## Grab (true) or free the mouse: the player, pause menu, dialogue, inspect view...
func capture_mouse(on: bool) -> void:
	_want_capture = on
	if device == Device.TOUCH:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


## True while the game is in "playing" mode (mouse grabbed, or wanted in touch/gamepad mode).
func mouse_captured() -> bool:
	if device == Device.TOUCH:
		return _want_capture
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (device == Device.GAMEPAD and _want_capture)


## Called for every screen touch / drag (here and by TouchControls, which consumes them).
func note_touch(event: InputEvent) -> void:
	_last_touch_ms = Time.get_ticks_msec()
	_mouse_travel = 0.0
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_fingers[touch.index] = true
		else:
			_fingers.erase(touch.index)
	if device != Device.TOUCH:
		_want_capture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _want_capture
		_set_device(Device.TOUCH)
		capture_mouse(_want_capture)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		note_touch(event)
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_switch_from_touch(Device.GAMEPAD)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE:
		_switch_from_touch(Device.GAMEPAD)
	elif event is InputEventKey and (event as InputEventKey).pressed and device == Device.GAMEPAD:
		_set_device(Device.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if device == Device.TOUCH:
			# Browsers report finger drags as mouse movement too.
			if not _fingers.is_empty() or Time.get_ticks_msec() - _last_touch_ms < 1000:
				return
			_mouse_travel += (event as InputEventMouseMotion).relative.length()
			if _mouse_travel > 80.0:
				_mouse_travel = 0.0
				_switch_from_touch(Device.KEYBOARD_MOUSE)
		elif device == Device.GAMEPAD and (event as InputEventMouseMotion).relative.length() > 8.0:
			_set_device(Device.KEYBOARD_MOUSE)


func _switch_from_touch(to: Device) -> void:
	var was_touch := device == Device.TOUCH
	_set_device(to)
	if was_touch:
		capture_mouse(_want_capture)


func _set_device(to: Device) -> void:
	if to == device:
		return
	device = to
	device_changed.emit(device)
	EventBus.input_device_changed.emit(device)
