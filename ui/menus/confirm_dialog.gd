class_name ConfirmDialog
extends Control
## A yes/no question in the VCR style, built in code (pause menu: restart, eject, main menu).
## ask() shows it with the safe answer ("NO") focused; `answered` fires once per question.
## Hosts send Esc to cancel().

signal answered(yes: bool)

var yes_button: Button
var no_button: Button
var _text: Label
var _list: MenuList


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	panel.add_child(box)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override(&"font_size", 22)
	box.add_child(_text)
	_list = MenuList.new()
	no_button = Button.new()
	no_button.name = &"No"
	yes_button = Button.new()
	yes_button.name = &"Yes"
	for button: Button in [no_button, yes_button]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_list.add_child(button)
	box.add_child(_list)
	no_button.pressed.connect(_answer.bind(false))
	yes_button.pressed.connect(_answer.bind(true))


func ask(question: String, yes_text: String, no_text: String = "NO - GO BACK") -> void:
	_text.text = question
	yes_button.text = yes_text
	no_button.text = no_text
	visible = true
	_list.focus_first()


func cancel() -> void:
	if visible:
		_answer(false)


func _answer(yes: bool) -> void:
	visible = false
	answered.emit(yes)
