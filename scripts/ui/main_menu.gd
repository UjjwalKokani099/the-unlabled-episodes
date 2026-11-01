extends Control
## VCR-OSD main menu over a live, grainy shot of Nikhil's room.
## CONTINUE (resume the checkpoint, or the hub), NEW GAME (confirm if it erases progress),
## TAPES (replay any unlocked tape; locked ones are blank cassettes), SETTINGS, QUIT.
## On the very first launch it goes straight into the intro instead.

@onready var _list: MenuList = $Panel/VBox/List
@onready var _continue: Button = $Panel/VBox/List/Continue
@onready var _new_game: Button = $Panel/VBox/List/NewGame
@onready var _tapes: Button = $Panel/VBox/List/Tapes
@onready var _settings_button: Button = $Panel/VBox/List/Settings
@onready var _quit: Button = $Panel/VBox/List/Quit
@onready var _panel: Control = $Panel
@onready var _tapes_panel: Control = $TapesPanel
@onready var _tape_list: MenuList = $TapesPanel/VBox/List
@onready var _tape_note: Label = $TapesPanel/VBox/Note
@onready var _confirm: Control = $Confirm
@onready var _confirm_list: MenuList = $Confirm/Panel/VBox/List
@onready var _confirm_no: Button = $Confirm/Panel/VBox/List/No
@onready var _confirm_yes: Button = $Confirm/Panel/VBox/List/Yes
@onready var _settings: SettingsMenu = $Settings
@onready var _clock: Label = $Clock
@onready var _whirr: AudioStreamPlayer = $Whirr


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.should_autoplay_intro():
		Game.play_intro.call_deferred()
		return
	_confirm.visible = false
	($Hum as AudioStreamPlayer).finished.connect(($Hum as AudioStreamPlayer).play)
	_tapes_panel.visible = false
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(func() -> void:
		if Game.has_progress():
			_show_only(_confirm)
			_confirm_list.focus_first()
		else:
			_start(Game.new_game))
	_tapes.pressed.connect(_open_tapes)
	_settings_button.pressed.connect(func() -> void:
		_show_only(null)
		_settings.open())
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_confirm_no.pressed.connect(_back_to_main)
	_confirm_yes.pressed.connect(func() -> void: _start(Game.new_game))
	_settings.closed.connect(_back_to_main)
	refresh()
	_list.focus_first.call_deferred()


func refresh() -> void:
	_continue.visible = Game.has_progress()


func _on_continue() -> void:
	_start(Game.load_checkpoint if Game.has_checkpoint() else Game.enter_hub)


func _start(action: Callable) -> void:
	_whirr.play()
	action.call()


func _open_tapes() -> void:
	for child in _tape_list.get_children():
		if child is Button:
			_tape_list.remove_child(child)
			child.queue_free()
	_tape_note.text = ""
	for chapter in Game.chapter_list.chapters:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if Game.is_unlocked(chapter.id):
			button.text = "■ %s   %s" % [chapter.title, chapter.subtitle]
			button.pressed.connect(func() -> void:
				if chapter.is_built():
					_start(func() -> void: Game.start_chapter(chapter.id))
				else:
					_tape_note.text = "NO SIGNAL — not recorded yet")
		else:
			button.text = "□ ──────────────"
			button.disabled = true
		_tape_list.add_child(button)
	var back := Button.new()
	back.text = "BACK"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back_to_main)
	_tape_list.add_child(back)
	_show_only(_tapes_panel)
	_tape_list.focus_first()


func _show_only(panel: Control) -> void:
	_panel.visible = false
	for p in [_tapes_panel, _confirm]:
		p.visible = p == panel


func _back_to_main() -> void:
	_tapes_panel.visible = false
	_confirm.visible = false
	_panel.visible = true
	_list.focus_first()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _settings.visible:
		_settings.close()
	elif _confirm.visible or _tapes_panel.visible:
		_back_to_main()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var t := Time.get_time_dict_from_system()
	var hour12: int = t.hour % 12
	_clock.text = "%s %d:%02d" % ["PM" if t.hour >= 12 else "AM", 12 if hour12 == 0 else hour12, t.minute]
