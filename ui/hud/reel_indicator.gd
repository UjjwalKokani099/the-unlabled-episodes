class_name ReelIndicator
extends Control
## Loading indicator: two cassette reels turning (fast-forward speed), the tape running
## between them; the take-up reel grows with `progress` (0..1). Drawn, no textures.

const REEL_RADIUS := 17.0
const GAP := 58.0
const SPIN := 7.0  # rad/s
const COLOR := Color(1, 1, 1, 0.85)

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var _angle: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(GAP + REEL_RADIUS * 2.0 + 16.0, REEL_RADIUS * 2.0 + 16.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_angle = fmod(_angle + SPIN * delta, TAU)
		queue_redraw()


func _draw() -> void:
	var y := size.y * 0.5
	var left := Vector2(size.x * 0.5 - GAP * 0.5, y)
	var right := Vector2(size.x * 0.5 + GAP * 0.5, y)
	# Tape wound on each reel: supply shrinks, take-up grows.
	var wound_left := lerpf(REEL_RADIUS - 2.0, 7.0, progress)
	var wound_right := lerpf(7.0, REEL_RADIUS - 2.0, progress)
	draw_circle(left, wound_left, Color(1, 1, 1, 0.18))
	draw_circle(right, wound_right, Color(1, 1, 1, 0.18))
	draw_line(left + Vector2(0, wound_left), right + Vector2(0, wound_right), COLOR, 1.5, true)
	for centre: Vector2 in [left, right]:
		draw_arc(centre, REEL_RADIUS, 0.0, TAU, 32, COLOR, 1.5, true)
		draw_arc(centre, 4.0, 0.0, TAU, 12, COLOR, 1.5, true)
		for i in 3:
			var a := _angle + TAU * i / 3.0
			draw_line(centre + Vector2.from_angle(a) * 4.0, centre + Vector2.from_angle(a) * (REEL_RADIUS - 3.0), COLOR, 1.5, true)
