extends CanvasLayer
## Test-room helper text in the top-left corner.
## [ and ] change mouse sensitivity (saved, so it survives a restart). F3 hides the text.
## F4 cycles the VHS screen effect: full / half / off.
## F9 loads the last checkpoint, F7 restarts the chapter.

const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint", &"crouch", &"flashlight", &"interact",
]

@onready var _label: Label = $Label

var _recent_events := PackedStringArray()


func _ready() -> void:
	Events.fired.connect(_on_event)


func _on_event(id: StringName) -> void:
	_recent_events.append(String(id))
	if _recent_events.size() > 4:
		_recent_events.remove_at(0)


func _process(_delta: float) -> void:
	if not _label.visible:
		return
	var held := PackedStringArray()
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			held.append(action)

	var lines := PackedStringArray()
	lines.append("FPS %d" % Engine.get_frames_per_second())
	lines.append("held: %s" % ("-" if held.is_empty() else ", ".join(held)))
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		var ground_speed := Vector2(player.velocity.x, player.velocity.z).length()
		lines.append("speed %.1f m/s   crouch %s   sprint %s   on floor %s   flashlight %s" % [
			ground_speed, _yn(player.is_crouching), _yn(player.is_sprinting),
			_yn(player.is_on_floor()), _yn(player.flashlight.visible)])
	var chapter := Game.current_chapter
	lines.append("chapter: %s   checkpoint saved: %s" % [
		chapter.id if chapter else "-", Game.saved_checkpoint_id() if Game.has_checkpoint() else "-"])
	lines.append("events: %s" % ("-" if _recent_events.is_empty() else " > ".join(_recent_events)))
	lines.append("mouse sensitivity %.2f   ([ / ] to change)" % Settings.mouse_sensitivity)
	lines.append("screen effects %.1f   (F4 to cycle)" % Settings.screen_effects)
	lines.append("F9: load checkpoint   F7: restart chapter")
	lines.append("Esc: pause menu   F3: hide this text")
	_label.text = "\n".join(lines)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_BRACKETLEFT:
			Settings.mouse_sensitivity -= 0.02
		KEY_BRACKETRIGHT:
			Settings.mouse_sensitivity += 0.02
		KEY_F3:
			_label.visible = not _label.visible
		KEY_F9:
			Game.load_checkpoint()
		KEY_F7:
			Game.restart_chapter()
		KEY_F4:
			Settings.screen_effects = 0.5 if Settings.screen_effects > 0.75 else (0.0 if Settings.screen_effects > 0.25 else 1.0)


func _yn(value: bool) -> String:
	return "yes" if value else "no"
