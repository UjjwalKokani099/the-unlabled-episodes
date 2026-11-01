extends Node3D
## Spins the ceiling fan blades (child "Blades") and loops its hum (child "Hum", optional).

@export var rpm: float = 180.0
@export var on: bool = true

@onready var _blades: Node3D = $Blades


func _ready() -> void:
	var hum := get_node_or_null("Hum") as AudioStreamPlayer3D
	if hum:
		hum.finished.connect(hum.play)
		if on:
			hum.play()


func _process(delta: float) -> void:
	if on:
		_blades.rotate_y(TAU * rpm / 60.0 * delta)
