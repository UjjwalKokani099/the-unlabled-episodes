class_name Crosshair
extends Control
## Small centre dot. Brightens/grows when looking at something usable and draws a
## ring while E is being held.

var focused: bool = false
var progress: float = 0.0:
	set(value):
		if not is_equal_approx(value, progress):
			progress = value
			queue_redraw()

var _focus_amount: float = 0.0


func _process(delta: float) -> void:
	var target := 1.0 if focused else 0.0
	if not is_equal_approx(_focus_amount, target):
		_focus_amount = move_toward(_focus_amount, target, delta * 6.0)
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := lerpf(1.5, 3.0, _focus_amount)
	draw_circle(center, radius, Color(1, 1, 1, lerpf(0.3, 0.9, _focus_amount)), true, -1.0, true)
	if progress > 0.0:
		draw_arc(center, 10.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(1, 1, 1, 0.85), 2.0, true)
