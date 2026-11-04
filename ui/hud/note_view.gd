class_name NoteView
extends CanvasLayer
## Full-screen "reading a piece of paper" view: diaries, registers, bills, phone chats.
## Open from anywhere:  get_tree().call_group("hud", "show_note", text, handwritten)
## E / Esc / click closes it. The player can't move while reading.

signal closed

var is_open: bool = false

@onready var _root: Control = $Root
@onready var _text: RichTextLabel = $Root/Paper/Margin/Text
@onready var _hint: Label = $Root/Hint

var _print_font: Font
var _hand_font: Font


func _ready() -> void:
	_root.visible = false
	_print_font = _text.get_theme_font(&"normal_font")
	_hand_font = load("res://assets/fonts/hand_raghu.tres")


func open(text: String, handwritten: bool = false) -> void:
	_text.add_theme_font_override(&"normal_font", _hand_font if handwritten else _print_font)
	_text.text = text
	_root.visible = true
	is_open = true
	_set_player_input(false)


func close() -> void:
	if not is_open:
		return
	_root.visible = false
	is_open = false
	_set_player_input(true)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") \
			or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		close()


func _set_player_input(enabled: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_enabled = enabled
