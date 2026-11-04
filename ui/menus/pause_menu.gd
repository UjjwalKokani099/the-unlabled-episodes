class_name PauseMenu
extends CanvasLayer
## Esc menu, part of the HUD scene (so every level has it). Pauses the game tree; this
## node keeps running (process_mode = Always). Inside a tape it also offers "restart
## from checkpoint" and "eject tape" (back to the hub). Leaving a chapter asks first
## (ConfirmDialog): progress since the last checkpoint is lost.

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

var confirm: ConfirmDialog
var _pending: Callable


func _ready() -> void:
	_root.visible = false
	confirm = ConfirmDialog.new()
	_root.add_child(confirm)
	confirm.answered.connect(_on_answered)
	_resume.pressed.connect(close)
	_restart.pressed.connect(func() -> void:
		_ask("Restart from the last checkpoint?\nAnything since then is lost.", "YES, RESTART", func() -> void:
			_leave()
			GameManager.load_checkpoint()))
	_settings_button.pressed.connect(func() -> void:
		_list.visible = false
		_settings.open())
	_eject.pressed.connect(func() -> void:
		_ask_if_in_chapter("Eject the tape and go back to the room?", "YES, EJECT", func() -> void:
			_leave()
			GameManager.return_to_hub()))
	_main_menu.pressed.connect(func() -> void:
		_ask_if_in_chapter("Quit to the main menu?", "YES, MAIN MENU", func() -> void:
			_leave()
			GameManager.go_to_main_menu()))
	_settings.closed.connect(func() -> void:
		_list.visible = true
		_settings_button.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") and not (is_open and event.is_action_pressed(&"ui_cancel")):
		return
	if confirm.visible:
		confirm.cancel()
	elif _settings.visible:
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
	InputManager.capture_mouse(false)
	AudioManager.set_muffled(true)
	EventBus.game_paused.emit(true)
	var chapter := GameManager.current_chapter
	_where.text = "%s - %s" % [chapter.title, chapter.subtitle] if chapter else ""
	_restart.visible = chapter != null and GameManager.has_checkpoint() and GameManager.checkpoint_chapter_id() == chapter.id
	_eject.visible = chapter != null
	_list.visible = true
	_root.visible = true
	_list.focus_first()


func close() -> void:
	_settings.close(true)
	confirm.visible = false
	is_open = false
	_root.visible = false
	get_tree().paused = false
	InputManager.capture_mouse(true)
	AudioManager.set_muffled(false)
	EventBus.game_paused.emit(false)


## Ask before `action`; the list hides while the question is up.
func _ask(question: String, yes_text: String, action: Callable) -> void:
	_pending = action
	_list.visible = false
	confirm.ask(question, yes_text)


## In a tape, leaving loses unsaved progress, so ask; in the hub just go.
func _ask_if_in_chapter(question: String, yes_text: String, action: Callable) -> void:
	if GameManager.current_chapter != null:
		_ask(question + "\nProgress since the last checkpoint is lost.", yes_text, action)
	else:
		action.call()


func _on_answered(yes: bool) -> void:
	if yes:
		_pending.call()
	else:
		_list.visible = true
		_list.focus_first()
	_pending = Callable()


func _can_open() -> bool:
	return not GameManager.is_transitioning() and not get_tree().paused


## Hide without unpausing: SceneLoader keeps the tree paused while it changes level.
func _leave() -> void:
	is_open = false
	_root.visible = false
	AudioManager.set_muffled(false)
	EventBus.game_paused.emit(false)
