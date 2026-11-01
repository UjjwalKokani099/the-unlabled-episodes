extends Node3D
## Main-menu background: Nikhil's dim room at night (tube light off, TV static and laptop
## glow only), a slowly drifting camera on the box of tapes, and a red REC dot blinking in
## the dark corner.

@onready var _camera: Camera3D = $Camera3D
@onready var _rec: Node3D = $RecDot

var _time: float = 0.0
var _base: Transform3D


func _ready() -> void:
	var room := $Room
	(room.get_node("TubeLight") as TubeLight).on = false
	(room.get_node("Van") as Node3D).visible = false
	(room.get_node("DeliveryBag") as Node3D).visible = false
	_camera.look_at_from_position(Vector3(0.75, 1.3, 2.0), Vector3(2.2, 0.35, 3.75))
	_base = _camera.transform


func _process(delta: float) -> void:
	_time += delta
	var sway := Basis.from_euler(Vector3(sin(_time * 0.13) * 0.012, sin(_time * 0.09) * 0.02, sin(_time * 0.05) * 0.004))
	_camera.transform = Transform3D(_base.basis * sway, _base.origin + Vector3(sin(_time * 0.07) * 0.04, 0, 0))
	_rec.visible = fmod(_time, 1.2) < 0.7
