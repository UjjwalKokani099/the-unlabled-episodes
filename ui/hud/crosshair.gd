class_name Crosshair
extends Control
## Small centre dot. Brightens/grows when looking at something usable, pulses when you use
## it, and draws a ring while E is being held.

var focused: bool = false
var progress: float = 0.0:
	set(value):
		if not is_equal_approx(value, progress):
			progress = value
			queue_redraw()

var _focus_amount: float = 0.0
var _pulse: float = 0.0


## A short swell of the dot: feedback that the use went through.
func pulse() -> void:
	_pulse = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	var target := 1.0 if focused else 0.0
	if not is_equal_approx(_focus_amount, target):
		_focus_amount = move_toward(_focus_amount, target, delta * 6.0)
		queue_redraw()
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 5.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var eased := 1.0 - pow(1.0 - _pulse, 2.0) if _pulse > 0.0 else 0.0
	var radius := lerpf(1.5, 3.0, _focus_amount) + 3.0 * eased * _pulse
	draw_circle(center, radius, Color(1, 1, 1, lerpf(0.3, 0.9, _focus_amount)), true, -1.0, true)
	if progress > 0.0:
		draw_arc(center, 10.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(1, 1, 1, 0.85), 2.0, true)
