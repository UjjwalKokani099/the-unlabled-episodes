extends Control
## First screen. CONTINUE resumes the saved checkpoint, START/TAPES goes to the hub,
## NEW GAME wipes progress (after a confirm), SETTINGS, QUIT.

@onready var _list: MenuList = $List
@onready var _continue: Button = $List/Continue
@onready var _tapes: Button = $List/Tapes
@onready var _new_game: Button = $List/NewGame
@onready var _settings_button: Button = $List/Settings
@onready var _quit: Button = $List/Quit
@onready var _title: Label = $Title
@onready var _confirm: Control = $Confirm
@onready var _confirm_list: MenuList = $Confirm/Panel/VBox/List
@onready var _confirm_no: Button = $Confirm/Panel/VBox/List/No
@onready var _confirm_yes: Button = $Confirm/Panel/VBox/List/Yes
@onready var _settings: SettingsMenu = $Settings
@onready var _hiss: AudioStreamPlayer = $Hiss

var _title_home: Vector2
var _glitch_left: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title_home = _title.position
	_confirm.visible = false
	_continue.pressed.connect(func() -> void: Game.load_checkpoint())
	_tapes.pressed.connect(func() -> void: Game.enter_hub())
	_new_game.pressed.connect(_ask_new_game)
	_settings_button.pressed.connect(func() -> void:
		_list.visible = false
		_settings.open())
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_confirm_no.pressed.connect(_close_confirm)
	_confirm_yes.pressed.connect(func() -> void: Game.new_game())
	_settings.closed.connect(func() -> void:
		_list.visible = true
		_settings_button.grab_focus())
	_hiss.finished.connect(_hiss.play)
	refresh()
	_list.focus_first.call_deferred()


## Show/hide items for the current save.
func refresh() -> void:
	var has_progress := Game.has_progress()
	_continue.visible = Game.has_checkpoint()
	if _continue.visible:
		var chapter := Game.get_chapter(Game.checkpoint_chapter_id())
		_continue.text = "CONTINUE  %s" % (chapter.title if chapter else "")
	_tapes.text = "TAPES" if has_progress else "START"
	_new_game.visible = has_progress


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _settings.visible:
		_settings.close()
	elif _confirm.visible:
		_close_confirm()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Now and then the title jumps sideways for a frame or two, like a bad tracking line.
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			_title.position = _title_home
	elif randf() < delta * 0.4:
		_glitch_left = randf_range(0.04, 0.12)
		_title.position = _title_home + Vector2(randf_range(-14.0, 14.0), 0.0)


func _ask_new_game() -> void:
	_list.visible = false
	_confirm.visible = true
	_confirm_list.focus_first()


func _close_confirm() -> void:
	_confirm.visible = false
	_list.visible = true
	_new_game.grab_focus()
