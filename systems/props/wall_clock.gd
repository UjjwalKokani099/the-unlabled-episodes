class_name WallClock
extends PropModel
## A clock model (assets/models/wall_clock, alarm_clock_01) whose hands show the time:
## inside a tape, the camcorder's clock (so the clock on the cabin wall agrees with the
## OSD, tape cuts included); otherwise the player's real local time (Nikhil's present).
## Hands are found by name (*hour*/*houd*, *minute*, *second*) and turn about local +Z.

## Turn the hands the other way (models whose face points along -Z).
@export var reverse: bool = false
## Stopped clocks are scarier. -1 = running, else seconds since midnight to stop at.
@export var stopped_at: int = -1

var _hour: Node3D
var _minute: Node3D
var _second: Node3D


func _ready() -> void:
	super()
	for node in find_children("*", "Node3D", true, false):
		var n := String(node.name).to_lower()
		if "second" in n:
			_second = node
		elif "minute" in n:
			_minute = node
		elif "hour" in n or "houd" in n:
			_hour = node


func seconds_now() -> int:
	if stopped_at >= 0:
		return stopped_at
	for node in get_tree().get_nodes_in_group("camcorder"):
		var camcorder := node as Camcorder
		if camcorder and camcorder.osd:
			return camcorder.osd.time_of_day()
	var t := Time.get_time_dict_from_system()
	return t.hour * 3600 + t.minute * 60 + t.second


func _process(_delta: float) -> void:
	var s := seconds_now()
	var sign := 1.0 if reverse else -1.0  # clockwise seen from the face
	if _second:
		_second.rotation.z = sign * TAU * (s % 60) / 60.0
	if _minute:
		_minute.rotation.z = sign * TAU * (s % 3600) / 3600.0
	if _hour:
		_hour.rotation.z = sign * TAU * (s % 43200) / 43200.0
