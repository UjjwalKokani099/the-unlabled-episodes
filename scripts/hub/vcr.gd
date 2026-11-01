class_name VCR
extends Node3D
## The hub VCR. Its prompt follows the Hub's state (insert the held tape / resume the
## saved checkpoint), and its clock blinks 12:00 like every VCR ever.

@onready var interactable: Interactable = $Interactable
@onready var clock: Label3D = $Clock
@onready var insert_sound: AudioStreamPlayer3D = $InsertSound

var _blink: float = 0.0


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	_blink += delta
	clock.visible = fmod(_blink, 1.0) < 0.5
	var hub := _hub()
	if hub:
		interactable.prompt = hub.vcr_prompt()
		var box_area := hub.room.get_node_or_null("TapeBox/Interactable") as Interactable
		if box_area:
			box_area.prompt = hub.box_prompt()


func _on_interacted(_by: Node3D) -> void:
	var hub := _hub()
	if hub:
		hub.use_vcr()


func _hub() -> Hub:
	return get_tree().get_first_node_in_group("hub") as Hub
