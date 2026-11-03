class_name DemoEnd
extends CanvasLayer
## End-of-demo card (hub): shown when Nikhil plays a tape that isn't built yet. VCR on-screen
## display style (ui/themes/vcr_theme.tres) over a blue screen that fades in from static.
## "BACK TO THE ROOM" closes it (`closed`), "MAIN MENU" leaves.

signal closed

const THEME := preload("res://ui/themes/vcr_theme.tres")

var _panel: Control
var _back: Button


func _ready() -> void:
	layer = 30  # above the HUD and subtitles, below the FPS counter (40)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = THEME
	add_child(root)
	_panel = root
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.06, 0.32)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var osd := Label.new()
	osd.text = "■ STOP"
	osd.position = Vector2(48, 36)
	root.add_child(osd)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override(&"separation", 14)
	root.add_child(box)
	var spotted := GameManager.spotted_count("t1_")
	for line in [
			["END OF DEMO", 44],
			["TAPE 01  ·  THE WATCHMAN  ·  WATCHED", 24],
			["SPOTTED HIM:  %d OF 3" % spotted, 24],
			["", 12],
			["The other tapes are still in the box.", 22],
			["Still no labels.", 22],
			["", 12],
			["Thank you for watching.", 22]]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", line[1])
		box.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 40)
	box.add_child(buttons)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "BACK TO THE ROOM"
	_back.pressed.connect(close)
	buttons.add_child(_back)
	var menu := Button.new()
	menu.name = "Menu"
	menu.text = "MAIN MENU"
	menu.pressed.connect(func() -> void:
		InputManager.capture_mouse(false)
		GameManager.go_to_main_menu())
	buttons.add_child(menu)
	InputManager.capture_mouse(false)
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 1.2)
	_back.grab_focus.call_deferred()


func close() -> void:
	InputManager.capture_mouse(true)
	closed.emit()
	queue_free()
