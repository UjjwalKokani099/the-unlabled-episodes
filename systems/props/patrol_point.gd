class_name PatrolPoint
extends Area3D
## Walking in counts one patrol stop: fires Events `event_id` once per point (remembered
## across checkpoint loads) and shows `label`.

@export var event_id: StringName = &"patrol_point"
@export var label: String = "Checked"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		var key := "patrol:" + str(owner.get_path_to(self) if owner else get_path())
		if body is Player and not GameManager.get_flag(key, false):
			GameManager.set_flag(key)
			EventBus.fire(event_id)
			get_tree().call_group("hud", "show_message", label))
