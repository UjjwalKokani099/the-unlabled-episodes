class_name PlateLog
extends Node3D
## The booth's plate log (story bible: "paper records"). Every vehicle served is written
## in Salim's hand with the camcorder time (GameManager flag "t2_log", so checkpoints keep
## it). Reading it while "Write the hour's plates in the log" is active fires `log_written`;
## after the fourth van it holds a line Salim didn't write (`log_read_late`).

const SALIM_FONT := "res://assets/fonts/hand_raghu.tres"
const STRANGER_FONT := "res://assets/fonts/hand_stranger.tres"

@onready var _area: Interactable = $Interactable


func _ready() -> void:
	_area.interacted.connect(read)


## Adds a line in Salim's hand (the director calls it when a toll is taken).
static func write(plate: String, note: String, time: String) -> void:
	var lines: Array = GameManager.get_flag("t2_log", [])
	lines = lines.duplicate()
	lines.append([time, plate, note])
	GameManager.set_flag("t2_log", lines)


func read(_by: Node3D = null) -> void:
	var to_fire: Array[StringName] = []
	if ObjectiveManager.is_active(&"log_hour"):
		to_fire.append(&"log_written")
	if ObjectiveManager.is_active(&"read_log"):
		to_fire.append(&"log_read_late")
	get_tree().call_group("hud", "show_note", page(&"log_read_late" in to_fire), false)
	for id in to_fire:
		EventBus.fire(id)


## The page as it reads now.
func page(late: bool = false) -> String:
	var text := "[b]NH-4 TOLL PLAZA — BOOTH 3 — VEHICLE LOG[/b]\n02/11/2001   Night shift: Salim Khan\n\n"
	text += "[font=%s]00:58   ---   Shift start. Float Rs 500. Radio OK.[/font]\n" % SALIM_FONT
	for line: Array in GameManager.get_flag("t2_log", []):
		text += "[font=%s]%s   %s   %s[/font]\n" % [SALIM_FONT, line[0], line[1], line[2]]
	if late or EventBus.has_fired(&"log_read_late"):
		text += "[font=%s]03:12   MH 04 AX 0312   Omni, white. Paid. Driver: S. KHAN. Passengers: 5.[/font]\n" % STRANGER_FONT
	return text
