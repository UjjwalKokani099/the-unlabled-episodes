class_name NPCWalker
extends Node3D
## Walks a character along fixed world points at a steady pace (no physics, no pathfinding:
## scripted walks like Mr. Deshmukh leaving at 3:12). Put the character scene as a child,
## facing -Z. Fires `waypoint_events[i]` (if set) on reaching point i, `arrived_event` at
## the end. Hidden until walk() unless `visible_before_walk`.

signal waypoint_reached(index: int)
signal arrived

@export var points: PackedVector3Array = PackedVector3Array()
@export var speed: float = 1.15
## Starts walking when this Events id fires (or call walk()).
@export var start_event: StringName
@export var start_delay: float = 0.0
## Events ids fired at each point, by index ("" = none).
@export var waypoint_events: PackedStringArray = PackedStringArray()
@export var arrived_event: StringName
@export var hide_at_end: bool = true
@export var visible_before_walk: bool = false
@export var step_sound: AudioStream
@export var step_interval: float = 0.55

var walking: bool = false
var _next: int = 0
var _step_time: float = 0.0
var _bob: float = 0.0
var _steps: AudioStreamPlayer3D
var _body: Node3D


func _ready() -> void:
	visible = visible_before_walk
	_body = get_child(0) as Node3D if get_child_count() > 0 else null
	if step_sound:
		_steps = AudioStreamPlayer3D.new()
		_steps.stream = step_sound
		_steps.unit_size = 6.0
		_steps.bus = &"SFX"
		add_child(_steps)
	if start_event != &"":
		EventBus.fired.connect(func(id: StringName) -> void:
			if id == start_event and not walking and not EventBus.replaying:
				if start_delay > 0.0:
					await get_tree().create_timer(start_delay).timeout
				walk())


func walk() -> void:
	if points.is_empty() or walking:
		return
	global_position = points[0]
	_next = 1
	walking = true
	visible = true
	_face(points[mini(1, points.size() - 1)])


## Skip to the end (tests, or a checkpoint already past the walk).
func finish() -> void:
	walking = false
	if not points.is_empty():
		global_position = points[points.size() - 1]
	if hide_at_end:
		visible = false


func _process(delta: float) -> void:
	if not walking:
		return
	if _next >= points.size():
		_end()
		return
	var target := points[_next]
	var to := target - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = target
		_reached(_next)
		_next += 1
		if _next < points.size():
			_face(points[_next])
	else:
		global_position += to.normalized() * step
	# Small walking bob + footsteps.
	_bob += delta * speed * 5.2
	if _body:
		_body.position.y = absf(sin(_bob)) * 0.025
	_step_time -= delta
	if _steps and _step_time <= 0.0:
		_step_time = step_interval
		_steps.pitch_scale = randf_range(0.9, 1.1)
		_steps.play()


func _reached(index: int) -> void:
	waypoint_reached.emit(index)
	if index < waypoint_events.size() and waypoint_events[index] != "":
		EventBus.fire(StringName(waypoint_events[index]))


func _end() -> void:
	walking = false
	if hide_at_end:
		visible = false
	arrived.emit()
	if arrived_event != &"":
		EventBus.fire(arrived_event)


func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_to(global_position) > 0.01:
		look_at(flat, Vector3.UP)
