extends CanvasLayer
## In-game HUD: crosshair dot, interaction prompt, hold ring, short messages.
##
## Any script can show a message without a reference to the HUD:
##     get_tree().call_group("hud", "show_message", "It's locked.")

@onready var crosshair: Crosshair = $Crosshair
@onready var prompt_label: Label = $Prompt
@onready var message_label: Label = $Message

var _player: Player
var _message_tween: Tween
var _key_name: String = ""


## Prompt fade (studio spec: 0.15 s, never a hard pop).
const PROMPT_FADE := 0.15

var _prompt_shown: bool = false
var _prompt_tween: Tween
## The save icon (shown 2 s on every checkpoint save).
var save_indicator: SaveIndicator


func _ready() -> void:
	add_to_group("hud")
	save_indicator = SaveIndicator.new()
	add_child(save_indicator)
	message_label.modulate.a = 0.0
	prompt_label.visible = false
	prompt_label.modulate.a = 0.0


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player:
			_player.interactor.used.connect(func(_t: Interactable) -> void: crosshair.pulse())
	var target: Interactable = null
	var hold := 0.0
	if _player:
		target = _player.interactor.focused
		hold = _player.interactor.hold_ratio

	crosshair.focused = target != null
	crosshair.progress = hold
	if (target != null) != _prompt_shown:
		_fade_prompt(target != null)
	if target:
		var verb := "Hold [%s]" if target.hold_time > 0.0 else "[%s]"
		prompt_label.text = (verb % _interact_key()) + " " + target.prompt


func _fade_prompt(show: bool) -> void:
	_prompt_shown = show
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if show:
		prompt_label.visible = true
	_prompt_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0 if show else 0.0, PROMPT_FADE)
	if not show:
		_prompt_tween.tween_callback(func() -> void: prompt_label.visible = false)


## Show a piece of paper / screen text (diary, register, bill, chat). See NoteView.
func show_note(text: String, handwritten: bool = false) -> void:
	($NoteView as NoteView).open(text, handwritten)


## Play a conversation (DialogueView). See systems/dialogue/dialogue.gd for the format.
func start_dialogue(path: String, start: String = "") -> void:
	($DialogueView as DialogueView).play(path, start)


## Hold an item close and turn it over (InspectView). See Inspectable.
func inspect(item: Inspectable) -> void:
	($InspectView as InspectView).open(item)


func show_message(text: String, duration: float = 2.5) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


## Name of the key bound to "interact" on this keyboard layout (e.g. "E"); "USE" (the
## on-screen button) in touch mode.
func _interact_key() -> String:
	if InputManager.touch_mode:
		return "USE"
	if _key_name.is_empty():
		_key_name = SettingsManager.key_name(&"interact")
	return _key_name
