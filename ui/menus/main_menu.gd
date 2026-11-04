extends Control
## Diegetic main menu: the VCR's blue on-screen menu, shown on the CRT in Nikhil's dim room
## (ui/menus/menu_backdrop.tscn). The menu UI lives in the `Screen` SubViewport; its
## texture is put on the TV glass, and input is forwarded to it (mouse positions mapped
## onto the curved glass, keys passed straight through).
## CONTINUE (resume the checkpoint, or the hub), NEW GAME (confirm if it erases progress),
## TAPES (replay any unlocked tape; locked ones are blank cassettes), SETTINGS, QUIT.
## Starting anything: the camera dives into the screen, then the VHS tape transition.
## On the very first launch it goes straight into the intro instead.

const UI := "Screen/UI/"
## Menu items are read off a TV across the room: bigger than a flat 2D menu.
## VT323 (the CRT's VCR font) runs small for its size, hence the large number.
const ITEM_FONT_SIZE := 40

var _starting: bool = false

@onready var _screen: SubViewport = $Screen
@onready var _backdrop_viewport: SubViewport = $Backdrop/Viewport
@onready var _backdrop: MenuBackdrop = $Backdrop/Viewport/Scene
@onready var _list: MenuList = get_node(UI + "Panel/VBox/List")
@onready var _continue: Button = get_node(UI + "Panel/VBox/List/Continue")
@onready var _new_game: Button = get_node(UI + "Panel/VBox/List/NewGame")
@onready var _tapes: Button = get_node(UI + "Panel/VBox/List/Tapes")
@onready var _settings_button: Button = get_node(UI + "Panel/VBox/List/Settings")
@onready var _quit: Button = get_node(UI + "Panel/VBox/List/Quit")
@onready var _panel: Control = get_node(UI + "Panel")
@onready var _tapes_panel: Control = get_node(UI + "TapesPanel")
@onready var _tape_list: MenuList = get_node(UI + "TapesPanel/VBox/List")
@onready var _tape_note: Label = get_node(UI + "TapesPanel/VBox/Note")
@onready var _confirm: Control = get_node(UI + "Confirm")
@onready var _confirm_list: MenuList = get_node(UI + "Confirm/Panel/VBox/List")
@onready var _confirm_no: Button = get_node(UI + "Confirm/Panel/VBox/List/No")
@onready var _confirm_yes: Button = get_node(UI + "Confirm/Panel/VBox/List/Yes")
@onready var _settings: SettingsMenu = get_node(UI + "Settings")
@onready var _clock: Label = get_node(UI + "Clock")
@onready var _whirr: AudioStreamPlayer = $Whirr


func _ready() -> void:
	InputManager.capture_mouse(false)
	if GameManager.should_autoplay_intro():
		GameManager.play_intro.call_deferred()
		return
	_backdrop.show_on_tv(_screen.get_texture())
	_confirm.visible = false
	($Hum as AudioStreamPlayer).finished.connect(($Hum as AudioStreamPlayer).play)
	_tapes_panel.visible = false
	for list in [_list, _confirm_list]:
		for button in list.get_children():
			if button is Button:
				button.add_theme_font_size_override(&"font_size", ITEM_FONT_SIZE)
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(func() -> void:
		if GameManager.has_progress():
			_show_only(_confirm)
			_confirm_list.focus_first()
		else:
			_start(GameManager.new_game))
	_tapes.pressed.connect(_open_tapes)
	_settings_button.pressed.connect(func() -> void:
		_show_only(null)
		_backdrop.frame(MenuBackdrop.Framing.CLOSE)
		_settings.open())
	_quit.pressed.connect(GameManager.quit_game)
	_confirm_no.pressed.connect(_back_to_main)
	_confirm_yes.pressed.connect(func() -> void: _start(GameManager.new_game))
	_settings.closed.connect(_back_to_main)
	refresh()
	_list.focus_first.call_deferred()


func refresh() -> void:
	_continue.visible = GameManager.has_progress()


## The button that has keyboard focus on the TV (tests use this).
func focused_control() -> Control:
	return _screen.gui_get_focus_owner()


func _on_continue() -> void:
	_start(GameManager.load_checkpoint if GameManager.has_checkpoint() else GameManager.enter_hub)


## Dive into the TV picture, then hand over to Game (which plays the tape transition).
func _start(action: Callable) -> void:
	if _starting:
		return
	_starting = true
	_whirr.play()
	($VHS as VHSEffect).glitch(0.8, 0.6)
	await _backdrop.frame(MenuBackdrop.Framing.DIVE, 0.55).finished
	action.call()
	_starting = false


func _open_tapes() -> void:
	for child in _tape_list.get_children():
		if child is Button:
			_tape_list.remove_child(child)
			child.queue_free()
	_tape_note.text = ""
	for chapter in GameManager.chapter_list.chapters:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.add_theme_font_size_override(&"font_size", ITEM_FONT_SIZE - 6)
		if GameManager.is_unlocked(chapter.id):
			button.text = "■ %s   %s" % [chapter.title, chapter.subtitle]
			button.pressed.connect(func() -> void:
				if chapter.is_built():
					_start(func() -> void: GameManager.start_chapter(chapter.id))
				else:
					_tape_note.text = "NO SIGNAL — not recorded yet")
		else:
			button.text = "□ ──────────────"
			button.disabled = true
		_tape_list.add_child(button)
	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override(&"font_size", ITEM_FONT_SIZE - 6)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back_to_main)
	_tape_list.add_child(back)
	_show_only(_tapes_panel)
	_backdrop.frame(MenuBackdrop.Framing.CLOSE)
	_tape_list.focus_first()


func _show_only(panel: Control) -> void:
	_panel.visible = false
	for p in [_tapes_panel, _confirm]:
		p.visible = p == panel


func _back_to_main() -> void:
	_tapes_panel.visible = false
	_confirm.visible = false
	_panel.visible = true
	_backdrop.frame(MenuBackdrop.Framing.IDLE)
	_list.focus_first()


# --- Input: everything goes to the TV picture -------------------------------------

func _input(event: InputEvent) -> void:
	if _starting:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and not _settings.is_waiting_for_key():
		if _settings.visible:
			_settings.close()
		elif _confirm.visible or _tapes_panel.visible:
			_back_to_main()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		var mouse := event as InputEventMouse
		# Backdrop renders the room at the window's size: same pixel coordinates.
		var scale := Vector2(_backdrop_viewport.size) / get_viewport_rect().size
		var uv := _backdrop.screen_uv_at(mouse.position * scale)
		if uv.x < 0.0:
			if event is InputEventMouseMotion:
				return  # off the glass: nothing to hover
			get_viewport().set_input_as_handled()
			return
		var copy := mouse.duplicate() as InputEventMouse
		copy.position = uv * Vector2(_screen.size)
		copy.global_position = copy.position
		_screen.push_input(copy, true)
	else:
		_screen.push_input(event)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var t := Time.get_time_dict_from_system()
	var hour12: int = t.hour % 12
	_clock.text = "%s %d:%02d" % ["PM" if t.hour >= 12 else "AM", 12 if hour12 == 0 else hour12, t.minute]
