extends Node3D
## Plays the intro (story bible + brief): VCR blue-screen load -> Sunday flea market at dusk,
## Nikhil walks past the stalls, finds the box, the vendor sells it without looking at him
## -> "THAT NIGHT" -> home, the box set down beside the VCR -> GameManager.finish_intro() (hub).
## Hold Space / Enter (ui_accept) to skip. Camera moves between Marker3Ds in $Shots.

const SKIP_HOLD := 0.8

@onready var _camera: Camera3D = $Camera3D
@onready var _blue: Control = $UI/Blue
@onready var _fade: ColorRect = $UI/Fade
@onready var _card: Label = $UI/Card
@onready var _skip: Label = $UI/Skip
@onready var _vhs = $Camcorder

var finished: bool = false
var _skip_time: float = 0.0
var _time: float = 0.0
var _fingers: int = 0  # touch play: holding a finger on the screen skips too


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_vhs.osd.visible = false
	var room := $Home/Room
	room.get_node("WorldEnvironment").queue_free()  # the market environment drives the sky
	(room.get_node("Van") as Node3D).visible = false
	(room.get_node("DeliveryBag") as Node3D).visible = false
	(room.get_node("TapeBox") as Node3D).visible = false
	_card.visible = false
	_play()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_fingers = maxi(_fingers + (1 if event.pressed else -1), 0)


func skip() -> void:
	_finish()


func _process(delta: float) -> void:
	_time += delta
	if Input.is_action_pressed(&"ui_accept") or Input.is_action_pressed(&"pause") or _fingers > 0:
		_skip_time += delta
		if _skip_time >= SKIP_HOLD:
			_finish()
	else:
		_skip_time = 0.0
	_skip.modulate.a = 0.35 + 0.65 * clampf(_skip_time / SKIP_HOLD, 0.0, 1.0)


func _play() -> void:
	# 1. VCR loading the tape: blue screen, PLAY, tracking noise.
	_blue.visible = true
	_vhs.glitch(1.0, 2.6)
	await _wait(2.4)
	_blue.visible = false
	_fade.color.a = 1.0
	_place("M0", "L0")
	await _fade_to(0.0, 1.0)
	# 2. Walk through the market.
	await _shot("M0", "M1", "L0", "L1", 6.0)
	await _shot("M1", "M2", "L1", "L2", 5.0)
	await _shot("M2", "M3", "L2", "L3", 5.0)
	await _shot("M3", "M4", "L3", "L4", 3.5)
	_say("Vendor", "Purane video tapes. Dedh sau, poora dabba.  (Old video tapes. 150 for the whole box.)", 4.0)
	await _wait(4.2)
	_say("Vendor", "Le jao. Wapas mat lana.  (Take it. Don't bring it back.)", 3.5)
	await _shot("M4", "M5", "L4", "L5", 3.5)
	# 3. That night.
	await _fade_to(1.0, 0.8)
	_card.text = "THAT NIGHT"
	_card.visible = true
	await _wait(1.8)
	_card.visible = false
	_place("H0", "HL0")
	await _fade_to(0.0, 0.8)
	await _shot("H0", "H1", "HL0", "HL1", 3.5)
	($Home/Room/TapeBox as Node3D).visible = true
	($Home/Thud as AudioStreamPlayer3D).play()
	_vhs.glitch(0.25, 0.4)
	await _wait(2.2)
	await _fade_to(1.0, 1.0)
	_finish()


func _finish() -> void:
	if finished or not is_inside_tree():
		return
	finished = true
	GameManager.finish_intro()


func _say(speaker: String, text: String, seconds: float) -> void:
	if not finished:
		get_tree().call_group("subtitles", "say", speaker, text, seconds)


func _marker(name: String) -> Vector3:
	return ($Shots.get_node(name) as Node3D).global_position


func _place(at: String, look: String) -> void:
	_camera.look_at_from_position(_marker(at), _marker(look))


## Move the camera from marker a to b while turning from look target la to lb (with a
## gentle walking bob).
func _shot(a: String, b: String, la: String, lb: String, seconds: float) -> void:
	if finished:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float) -> void:
		var pos := _marker(a).lerp(_marker(b), t) + Vector3(0, sin(_time * 7.0) * 0.025, 0)
		_camera.look_at_from_position(pos, _marker(la).lerp(_marker(lb), t)), 0.0, 1.0, seconds)
	await tween.finished


func _fade_to(alpha: float, seconds: float) -> void:
	if finished:
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


func _wait(seconds: float) -> void:
	if finished:
		return
	await get_tree().create_timer(seconds).timeout
