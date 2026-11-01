class_name TriggerZone
extends Area3D
## Invisible box that fires an Events id when the player walks in.
## Give it a CollisionShape3D child. Pair it with EventReaction nodes to build scares.

signal triggered

## Events id fired on enter.
@export var event_id: StringName
## Fire only the first time.
@export var once: bool = true
## If set, the zone does nothing until this Events id has fired (e.g. &"vhs_tape").
## If the player is already inside when it arms, it fires right away.
@export var armed_by: StringName

var _has_fired: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	body_entered.connect(_on_body_entered)
	if armed_by != &"":
		Events.fired.connect(_on_event)


func is_armed() -> bool:
	return armed_by == &"" or Events.has_fired(armed_by)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_try_fire()


func _on_event(id: StringName) -> void:
	if id != armed_by:
		return
	for body in get_overlapping_bodies():
		if body is Player:
			_try_fire()
			return


func _try_fire() -> void:
	if not is_armed() or (once and _has_fired):
		return
	_has_fired = true
	triggered.emit()
	Events.fire(event_id)
