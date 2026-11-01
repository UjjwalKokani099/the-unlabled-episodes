extends Node
## Camcorder overlay root (ui/hud/camcorder.tscn): OSD + VHS effect.
## Anything can glitch the picture: get_tree().call_group("camcorder", "glitch", 0.8, 0.5)

@onready var osd: CamcorderOSD = $OSDLayer/OSD
@onready var vhs: VHSEffect = $VHSLayer/VHS


func _ready() -> void:
	add_to_group("camcorder")


func glitch(amount: float, duration: float = 0.5) -> void:
	vhs.glitch(amount, duration)
