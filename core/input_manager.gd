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
