class_name MenuList
extends VBoxContainer
## A vertical list of Buttons with a VCR-menu feel: hovering with the mouse moves the
## keyboard focus (so there's only ever one highlighted item), and it beeps on moving
## and selecting. Arrow keys / Enter work out of the box.

const BLIP := preload("res://assets/audio/sfx/ui_blip.wav")
const SELECT := preload("res://assets/audio/sfx/ui_select.wav")

var _sound: AudioStreamPlayer
var _quiet: bool = false


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	_sound.volume_db = -6.0
	add_child(_sound)
	for child in get_children():
		if child is Button:
			_wire(child)
	child_entered_tree.connect(func(node: Node) -> void:
		if node is Button:
			_wire(node))


## Focus the first visible, enabled button (without a beep).
func focus_first() -> void:
	for child in get_children():
		var button := child as Button
		if button and button.visible and not button.disabled:
			_quiet = true
			button.grab_focus()
			_quiet = false
			return


func _wire(button: Button) -> void:
	if button.has_meta(&"menu_wired"):
		return
	button.set_meta(&"menu_wired", true)
	button.mouse_entered.connect(func() -> void:
		if button.visible and not button.disabled and not button.has_focus():
			button.grab_focus())
	button.focus_entered.connect(func() -> void: _play(BLIP))
	button.pressed.connect(func() -> void: _play(SELECT))


func _play(stream: AudioStream) -> void:
	if _quiet or not is_inside_tree():
		return
	_sound.stream = stream
	_sound.play()
