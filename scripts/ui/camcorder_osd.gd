class_name CamcorderOSD
extends Control
## The camcorder's on-screen display: viewfinder corners, blinking REC, battery meter and
## a running date/time stamp. Drawn under the VHS effect so it looks "recorded".

const MONTHS := ["JAN.", "FEB.", "MAR.", "APR.", "MAY", "JUN.", "JUL.", "AUG.", "SEP.", "OCT.", "NOV.", "DEC."]
const CORNER_MARGIN := 28.0
const CORNER_LENGTH := 38.0
const LINE_COLOR := Color(1, 1, 1, 0.8)
const REC_COLOR := Color(0.95, 0.12, 0.1)

## When the tape starts, as "YYYY-MM-DDTHH:MM:SS". Each chapter sets its own.
@export var start_datetime: String = "1998-10-31T23:42:00"
@export var recording: bool = true
## 0..1. Shown as 4 bars.
@export_range(0.0, 1.0) var battery_level: float = 0.75:
	set(value):
		battery_level = clampf(value, 0.0, 1.0)
		queue_redraw()

var elapsed: float = 0.0
var _start_unix: int = 0
var _shown_second: int = -1
var _rec_on: bool = true

@onready var _rec_label: Label = $Rec
@onready var _date_label: Label = $Date
@onready var _time_label: Label = $Time


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_unix = Time.get_unix_time_from_datetime_string(start_datetime)
	_update_clock()


func _process(delta: float) -> void:
	elapsed += delta
	var rec_on := recording and fmod(elapsed, 1.0) < 0.6
	if rec_on != _rec_on:
		_rec_on = rec_on
		_rec_label.visible = rec_on
		queue_redraw()
	if int(elapsed) != _shown_second:
		_update_clock()


func _update_clock() -> void:
	_shown_second = int(elapsed)
	var dt := Time.get_datetime_dict_from_unix_time(_start_unix + _shown_second)
	var hour12: int = dt.hour % 12
	if hour12 == 0:
		hour12 = 12
	_time_label.text = "%s %d:%02d:%02d" % ["PM" if dt.hour >= 12 else "AM", hour12, dt.minute, dt.second]
	_date_label.text = "%s %d %d" % [MONTHS[dt.month - 1], dt.day, dt.year]


func _draw() -> void:
	var m := CORNER_MARGIN
	var l := CORNER_LENGTH
	var w := size.x
	var h := size.y
	for corner in [Vector2(m, m), Vector2(w - m, m), Vector2(m, h - m), Vector2(w - m, h - m)]:
		var sx := 1.0 if corner.x < w * 0.5 else -1.0
		var sy := 1.0 if corner.y < h * 0.5 else -1.0
		draw_line(corner, corner + Vector2(l * sx, 0), LINE_COLOR, 2.0)
		draw_line(corner, corner + Vector2(0, l * sy), LINE_COLOR, 2.0)

	if _rec_on:
		draw_circle(_rec_label.position + Vector2(-14, _rec_label.size.y * 0.5), 7.0, REC_COLOR, true, -1.0, true)

	# Battery: outline, nub, 4 bars.
	var origin := Vector2(m + 18, h - m - 40)
	var body := Rect2(origin, Vector2(46, 20))
	draw_rect(body, LINE_COLOR, false, 2.0)
	draw_rect(Rect2(origin + Vector2(46, 6), Vector2(4, 8)), LINE_COLOR)
	var bars := ceili(battery_level * 4.0)
	for i in bars:
		draw_rect(Rect2(origin + Vector2(4 + i * 10.5, 4), Vector2(8, 12)), LINE_COLOR)
