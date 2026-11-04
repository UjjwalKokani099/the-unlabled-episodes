class_name Boot
extends Control
## First thing the game shows (project main scene): black, the studio card fading in with a
## sting (3 s; any key skips it), then the content warning ("PRESS ANY KEY", which is also the
## browser's audio-unlock gesture on the web build), then the main menu (which plays the
## intro on the very first launch). Studio name: data/credits.json "studio" / "presents".

signal stage_changed(stage: Stage)

enum Stage { STUDIO, WARNING, LEAVING }

const STING := preload("res://assets/audio/sfx/boot_sting.wav")
const CREDITS_PATH := "res://data/credits.json"
const STUDIO_SECONDS := 3.0
const FADE := 0.7
## Keys pressed sooner than this after the warning appears are ignored (no accidental skip).
const WARNING_GUARD := 0.6
const WARNING_TEXT := "UNLABELED is a horror game. It contains death, stalking and \
psychological horror, sudden loud sounds, flashing lights and heavy VHS distortion.\n\n\
Flashing and camera motion can be reduced in Settings > Accessibility."

var stage: Stage = Stage.STUDIO
var _studio: Control
var _warning: Control
var _prompt: Label
var _sting: AudioStreamPlayer
var _tween: Tween
var _warning_time: float = 0.0


func _ready() -> void:
	InputManager.capture_mouse(false)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_studio = _build_studio()
	_warning = _build_warning()
	_sting = AudioStreamPlayer.new()
	_sting.stream = STING
	_sting.bus = &"SFX"
	_sting.volume_db = -4.0
	add_child(_sting)
	_play_studio()


func _process(delta: float) -> void:
	if stage == Stage.WARNING:
		_warning_time += delta
		_prompt.modulate.a = 0.35 + 0.65 * absf(sin(_warning_time * 2.2))


func _input(event: InputEvent) -> void:
	if not _is_press(event):
		return
	get_viewport().set_input_as_handled()
	if stage == Stage.STUDIO:
		_show_warning()
	elif stage == Stage.WARNING and _warning_time >= WARNING_GUARD:
		_leave()


## Skip straight on (tests, and "any key" during the studio card).
func advance() -> void:
	if stage == Stage.STUDIO:
		_show_warning()
	elif stage == Stage.WARNING:
		_leave()


func _play_studio() -> void:
	_studio.modulate.a = 0.0
	_sting.play()
	_tween = create_tween()
	_tween.tween_property(_studio, "modulate:a", 1.0, FADE).set_delay(0.3)
	_tween.tween_interval(STUDIO_SECONDS - FADE * 2.0 - 0.3)
	_tween.tween_property(_studio, "modulate:a", 0.0, FADE)
	_tween.tween_callback(_show_warning)


func _show_warning() -> void:
	if stage != Stage.STUDIO:
		return
	if _tween:
		_tween.kill()
	stage = Stage.WARNING
	_warning_time = 0.0
	_studio.visible = false
	_warning.modulate.a = 0.0
	_warning.visible = true
	_tween = create_tween()
	_tween.tween_property(_warning, "modulate:a", 1.0, FADE)
	stage_changed.emit(stage)


func _leave() -> void:
	if stage == Stage.LEAVING:
		return
	stage = Stage.LEAVING
	stage_changed.emit(stage)
	SceneLoader.change_scene(GameManager.MAIN_MENU_PATH)


func _is_press(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch:
		return event.is_pressed()
	if event is InputEventMouseButton:
		return event.is_pressed() and event.device != InputEvent.DEVICE_ID_EMULATION
	return false


func _build_studio() -> Control:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	var studio_name := "UNLABELED"
	var presents := ""
	if data is Dictionary:
		studio_name = (data as Dictionary).get("studio", studio_name)
		presents = (data as Dictionary).get("presents", "")
	var center := _centered()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 14)
	center.add_child(box)
	var spaced := FontVariation.new()
	spaced.base_font = load("res://assets/fonts/typewriter.tres")
	spaced.spacing_glyph = 8
	var title := _label(studio_name, spaced, 46, Color(0.92, 0.9, 0.86))
	box.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(0.85, 0.12, 0.1, 0.9)  # the red of a REC light
	rule.custom_minimum_size = Vector2(64, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	if presents != "":
		box.add_child(_label(presents, load("res://assets/fonts/ui.tres"), 22, Color(1, 1, 1, 0.55)))
	return center


func _build_warning() -> Control:
	var center := _centered()
	center.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 28)
	box.custom_minimum_size.x = 760
	center.add_child(box)
	var vcr: Font = load("res://assets/fonts/vcr.tres")
	box.add_child(_label("CONTENT WARNING", vcr, 44, Color(1, 1, 1, 0.92)))
	var body := _label(WARNING_TEXT, load("res://assets/fonts/ui.tres"), 24, Color(1, 1, 1, 0.78))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	_prompt = _label("PRESS ANY KEY", vcr, 30, Color(1, 1, 1, 0.9))
	box.add_child(_prompt)
	return center


func _centered() -> CenterContainer:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return center


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
