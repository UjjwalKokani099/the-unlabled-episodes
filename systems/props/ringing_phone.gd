class_name RingingPhone
extends Node3D
## A phone, intercom or bell panel. When `ring_event` fires it rings (looping sound, blinking
## "Led" child if there is one) until answered: using it then fires `answered_event`.
## Used while quiet: fires `use_event` and shows `idle_message`. Child: Interactable.
## Survives checkpoints: rings again after a load if it rang and was never answered.

signal answered
signal used

@export var ring_event: StringName
@export var answered_event: StringName
@export var use_event: StringName
@export var idle_message: String = ""
@export var ring_sound: AudioStream
@export var ring_volume_db: float = -4.0
@export var answer_prompt: String = "Answer"

var ringing: bool = false
var _idle_prompt: String
var _player: AudioStreamPlayer3D
var _blink: float = 0.0

@onready var _area: Interactable = $Interactable
@onready var _led: Node3D = get_node_or_null("Led")


func _ready() -> void:
	_idle_prompt = _area.prompt
	_player = AudioStreamPlayer3D.new()
	_player.stream = ring_sound
	_player.volume_db = ring_volume_db
	_player.unit_size = 8.0
	_player.bus = &"SFX"
	add_child(_player)
	_player.finished.connect(func() -> void:
		if ringing:
			_player.play())
	_area.interacted.connect(_on_used)
	if ring_event != &"":
		EventBus.fired.connect(func(id: StringName) -> void:
			if id == ring_event and not EventBus.replaying:
				ring())
		if EventBus.has_fired(ring_event) and not EventBus.has_fired(answered_event):
			ring.call_deferred()
	if _led:
		_led.visible = false


func ring() -> void:
	if ringing:
		return
	ringing = true
	_area.prompt = answer_prompt
	if ring_sound:
		_player.play()


func stop() -> void:
	ringing = false
	_area.prompt = _idle_prompt
	_player.stop()
	if _led:
		_led.visible = false


func _process(delta: float) -> void:
	if ringing and _led:
		_blink += delta
		_led.visible = fmod(_blink, 0.5) < 0.25


func _on_used(_by: Node3D) -> void:
	if ringing:
		stop()
		answered.emit()
		if answered_event != &"":
			EventBus.fire(answered_event)
		return
	used.emit()
	if use_event != &"":
		EventBus.fire(use_event)
	if idle_message != "":
		get_tree().call_group("hud", "show_message", idle_message, 3.0)
