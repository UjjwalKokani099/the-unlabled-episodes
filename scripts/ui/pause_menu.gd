class_name PauseMenu
extends CanvasLayer
## Esc menu, part of the HUD scene (so every level has it). Pauses the game tree; this
## node keeps running (process_mode = Always). Inside a tape it also offers "restart
## from checkpoint" and "eject tape" (back to the hub).

var is_open: bool = false

@onready var _root: Control = $Root
@onready var _list: MenuList = $Root/List
@onready var _resume: Button = $Root/List/Resume
@onready var _restart: Button = $Root/List/Restart
@onready var _settings_button: Button = $Root/List/Settings
@onready var _eject: Button = $Root/List/Eject
@onready var _main_menu: Button = $Root/List/MainMenu
@onready var _where: Label = $Root/Where
@onready var _settings: SettingsMenu = $Root/Settings


func _ready() -> void:
	_root.visible = false
	_resume.pressed.connect(close)
	_restart.pressed.connect(func() -> void:
		_leave()
		Game.load_checkpoint())
	_settings_button.pressed.connect(func() -> void:
		_list.visible = false
		_settings.open())
	_eject.pressed.connect(func() -> void:
		_leave()
		Game.return_to_hub())
	_main_menu.pressed.connect(func() -> void:
		_leave()
		Game.go_to_main_menu())
	_settings.closed.connect(func() -> void:
		_list.visible = true
		_settings_button.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _settings.visible:
		_settings.close()
	elif is_open:
		close()
	elif _can_open():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var chapter := Game.current_chapter
	_where.text = "%s - %s" % [chapter.title, chapter.subtitle] if chapter else ""
	_restart.visible = chapter != null and Game.has_checkpoint() and Game.checkpoint_chapter_id() == chapter.id
	_eject.visible = chapter != null
	_list.visible = true
	_root.visible = true
	_list.focus_first()


func close() -> void:
	_settings.close()
	is_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _can_open() -> bool:
	return not Game.is_transitioning() and not get_tree().paused


## Hide without unpausing: Game keeps the tree paused while it changes level.
func _leave() -> void:
	is_open = false
	_root.visible = false
