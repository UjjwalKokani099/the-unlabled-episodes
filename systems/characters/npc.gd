class_name NPC
extends CharacterBody3D
## Reusable NPC (assets/characters/npc.tscn). Put a character model under `Model` (a
## assets/characters/*.tscn, or later a Blender/Mixamo model with the same layout).
##
## - Walks to points with its NavigationAgent3D (needs a NavigationRegion3D in the level,
##   e.g. NavBaker); falls back to walking straight if there's no path.
## - Idle/walk: plays "idle"/"walk"/"talk" on an AnimationPlayer inside Model if there is one,
##   otherwise a small procedural breathe + walk bob on Model/Body.
## - Head tracking: turns Model/Body/Head towards the player within `look_distance`.
##   `uncanny` lets the head turn much further than a neck should, and snap.
## - Talk: the Talk Interactable plays `dialogue` (res://data/dialogue/*.json) in the HUD.
## Children: Model, Agent (NavigationAgent3D), Talk (Interactable), CollisionShape3D.

signal arrived
signal talked(last_node: String)

@export var display_name: String = "Someone"
@export_file("*.json") var dialogue: String = ""
@export var dialogue_start: String = ""
@export var talk_prompt: String = "Talk"
## Events id fired after each conversation.
@export var talked_event: StringName
@export var walk_speed: float = 1.1
@export var turn_speed: float = 6.0
@export_group("Look at the player")
@export var look_at_player: bool = true
@export var look_distance: float = 4.5
@export var head_limit_deg: float = 70.0
## Turns the head up to 150 degrees and snaps to it: something is wrong with this one.
@export var uncanny: bool = false
@export_group("")
## Hidden, no collision, nothing running while false.
@export var active: bool = true:
	set(value):
		active = value
		if is_node_ready():
			_apply_active()

var walking: bool = false
var talking: bool = false
var _target: Vector3
var _time: float = 0.0
var _head_yaw: float = 0.0
var _head_pitch: float = 0.0
var _body: Node3D
var _head: Node3D
var _anim: AnimationPlayer
var _body_base: Vector3

@onready var model: Node3D = $Model
@onready var agent: NavigationAgent3D = $Agent
@onready var talk_area: Interactable = $Talk


func _ready() -> void:
	_body = model.get_node_or_null("Body") as Node3D
	if _body == null and model.get_child_count() > 0:
		_body = model.get_child(0).get_node_or_null("Body") as Node3D
	_head = model.find_child("Head", true, false) as Node3D
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _body:
		_body_base = _body.position
	talk_area.prompt = "Talk to %s" % display_name if talk_prompt == "Talk" else talk_prompt
	talk_area.interacted.connect(func(_by: Node3D) -> void: talk())
	talk_area.enabled = dialogue != ""
	agent.velocity_computed.connect(func(v: Vector3) -> void: velocity = Vector3(v.x, velocity.y, v.z))
	_apply_active()


## Walk to a world position. Await `arrived`.
func walk_to(target: Vector3) -> void:
	_target = target
	agent.target_position = target
	walking = true


func stop() -> void:
	walking = false
	velocity = Vector3(0, velocity.y, 0)


## Turn the whole body to face a point.
func face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)


## Starts the conversation (also what pressing E on the NPC does).
func talk() -> void:
	if dialogue == "" or talking:
		return
	var view := _dialogue_view()
	if view == null:
		return
	talking = true
	stop()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and not uncanny:  # the uncanny ones don't turn their body to you
		face(player.global_position)
	_play_anim(&"talk")
	view.play(dialogue, dialogue_start)
	var last: String = await view.finished
	talking = false
	talked.emit(last)
	if talked_event != &"":
		EventBus.fire(talked_event)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if walking:
		var next := _target
		if not agent.is_navigation_finished() and agent.get_current_navigation_path().size() > 0:
			next = agent.get_next_path_position()
		var to := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
		var remaining := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
		if remaining < 0.35:
			stop()
			arrived.emit.call_deferred()  # listeners may switch us off; not mid-physics step
		elif to.length() > 0.01:
			var v := to.normalized() * walk_speed
			velocity = Vector3(v.x, velocity.y, v.z)
			var yaw := atan2(-v.x, -v.z)
			rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_speed * delta))
	else:
		velocity.x = move_toward(velocity.x, 0, 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 4.0 * delta)
	move_and_slide()


func _process(delta: float) -> void:
	_time += delta
	_animate()
	_track_head(delta)


func _animate() -> void:
	if _anim:
		_play_anim(&"talk" if talking else (&"walk" if walking else &"idle"))
		return
	if _body == null:
		return
	# Procedural stand-in: breathing when still, a bob while walking.
	if walking:
		_body.position = _body_base + Vector3(0, absf(sin(_time * walk_speed * 5.5)) * 0.03, 0)
	else:
		_body.position = _body_base + Vector3(0, sin(_time * 1.6) * 0.004, 0)


func _track_head(delta: float) -> void:
	if _head == null:
		return
	var yaw := 0.0
	var pitch := 0.0
	var camera := get_viewport().get_camera_3d()
	if look_at_player and camera and camera.global_position.distance_to(_head.global_position) < look_distance:
		# Direction to the camera in the body's space (body faces -Z).
		var local := (_head.get_parent() as Node3D).global_transform.affine_inverse() * camera.global_position \
			- _head.position
		yaw = atan2(-local.x, -local.z)
		pitch = atan2(local.y, Vector2(local.x, local.z).length())
		var limit := deg_to_rad(150.0 if uncanny else head_limit_deg)
		if absf(yaw) > limit:
			yaw = 0.0 if not uncanny else clampf(yaw, -limit, limit)
		yaw = clampf(yaw, -limit, limit)
		pitch = clampf(pitch, -0.5, 0.4)
	var rate := 30.0 if uncanny else 5.0
	_head_yaw = lerp_angle(_head_yaw, yaw, 1.0 - exp(-rate * delta))
	_head_pitch = lerpf(_head_pitch, pitch, 1.0 - exp(-rate * delta))
	_head.rotation = Vector3(_head_pitch, _head_yaw, 0)


## Current head turn in degrees (tests, debugging).
func head_yaw_deg() -> float:
	return rad_to_deg(_head_yaw)


func _play_anim(anim_name: StringName) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.25)


func _apply_active() -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	$CollisionShape3D.disabled = not active
	talk_area.enabled = active and dialogue != ""


func _dialogue_view() -> DialogueView:
	for hud in get_tree().get_nodes_in_group("hud"):
		var view := hud.get_node_or_null("DialogueView") as DialogueView
		if view:
			return view
	return null
