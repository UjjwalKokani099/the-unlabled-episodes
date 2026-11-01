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


func _ready() -> void:
	add_to_group("hud")
	message_label.modulate.a = 0.0
	prompt_label.visible = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	var target: Interactable = null
	var hold := 0.0
	if _player:
		target = _player.interactor.focused
		hold = _player.interactor.hold_ratio

	crosshair.focused = target != null
	crosshair.progress = hold
	prompt_label.visible = target != null
	if target:
		var verb := "Hold [%s]" if target.hold_time > 0.0 else "[%s]"
		prompt_label.text = (verb % _interact_key()) + " " + target.prompt


## Show a piece of paper / screen text (diary, register, bill, chat). See NoteView.
func show_note(text: String, handwritten: bool = false) -> void:
	($NoteView as NoteView).open(text, handwritten)


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


## Name of the key bound to "interact" on this keyboard layout (e.g. "E").
func _interact_key() -> String:
	if _key_name.is_empty():
		_key_name = "E"
		for event in InputMap.action_get_events(&"interact"):
			var key := event as InputEventKey
			if key:
				var keycode := DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
				_key_name = OS.get_keycode_string(keycode)
				break
	return _key_name
