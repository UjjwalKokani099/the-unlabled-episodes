class_name TollVehicle
extends AnimatableBody3D
## A vehicle on the toll lane (Tape 2). Drives in along -Z from `start_z`, brakes to a stop
## with its driver's window at the booth (`stop_z`), idles, and when the barrier lifts drives
## off to `end_z` and disappears. The moving node is the body itself (AnimatableBody3D only
## syncs collision when its own transform changes), so the player can't walk through it.
## Children from tools/gen_tape02.py: Body (the look), Driver, Passengers/*, Headlights,
## Tail lights, Engine (AudioStreamPlayer3D, idle loop), CollisionShape3D.

signal arrived
signal gone

enum State { PARKED, ARRIVING, WAITING, LEAVING }

@export var plate: String = "MH 12 AB 1234"
@export var start_z: float = 120.0
@export var stop_z: float = 0.0
@export var end_z: float = -140.0
## Cruise speed (m/s) far out; brakes over the last `brake_distance` metres.
@export var speed: float = 14.0
@export var brake_distance: float = 22.0
## Tests: < 1 speeds everything up.
@export var time_scale: float = 1.0

var state: State = State.PARKED
var paid: bool = false
var _v: float = 0.0

@onready var _engine: AudioStreamPlayer3D = get_node_or_null("Engine")


func _ready() -> void:
	sync_to_physics = false
	park()
	if _engine:
		_engine.finished.connect(func() -> void:
			if state != State.PARKED:
				_engine.play())


## Out of sight and silent (start of the night, after it has gone).
func park() -> void:
	state = State.PARKED
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	position.z = start_z
	_set_collision(false)
	if _engine:
		_engine.stop()


func drive_up() -> void:
	paid = false
	state = State.ARRIVING
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	position.z = start_z
	_v = speed
	_set_collision(true)
	if _engine:
		_engine.play()


## Put it at the window at once (checkpoint restore, tests).
func place_at_window() -> void:
	drive_up()
	position.z = stop_z
	_v = 0.0
	state = State.WAITING


func leave() -> void:
	if state != State.WAITING:
		return
	state = State.LEAVING
	_v = 0.0


func is_waiting() -> bool:
	return state == State.WAITING


func _physics_process(delta: float) -> void:
	var dt := delta / maxf(time_scale, 0.001)
	match state:
		State.ARRIVING:
			var left := position.z - stop_z
			var target := speed if left > brake_distance else maxf(speed * sqrt(maxf(left, 0.0) / brake_distance), 0.6)
			_v = move_toward(_v, target, 9.0 * dt)
			position.z = maxf(position.z - _v * dt, stop_z)
			if position.z <= stop_z + 0.01:
				state = State.WAITING
				_v = 0.0
				arrived.emit()
		State.LEAVING:
			_v = move_toward(_v, speed, 3.5 * dt)
			position.z -= _v * dt
			if position.z <= end_z:
				park()
				gone.emit()


func _set_collision(on: bool) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = not on
