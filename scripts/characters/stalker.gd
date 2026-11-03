class_name Stalker
extends Node
## The Cameraman as a threat (docs/villain_cameraman.md). Child of an NPC (scenes/characters/
## npc.tscn with the Cameraman model under Model); drives its walking.
##
## He never runs and never touches anyone. He PATROLs, and when the player is in his shot
## ("exposure": inside his camera's view, in line of sight, not hiding) he HUNTs: walks to
## where he last saw them, camera up. Held in frame long enough (exposure 1), the tape loses
## tracking: CAUGHT -> static -> the last checkpoint reloads. Lose him (break line of sight,
## crouch in a HidingSpot) and he SEARCHes nearby, then goes back to his patrol.
## FOLLOWING: keeps his distance behind the player, only moving while unwatched.
## Level scripts switch states with start_patrol() / follow() / stop().

signal caught
signal state_changed(state: State)

enum State { ABSENT, WATCHING, FOOTAGE_ONLY, FOLLOWING, PATROL, HUNT, SEARCH, CAUGHT, FINAL }

## His shot: half-angle and range.
@export var view_angle_deg: float = 45.0
@export var view_range: float = 16.0
## Seconds held in frame before he has you, far away / up close.
@export var seconds_to_catch_far: float = 3.2
@export var seconds_to_catch_near: float = 1.2
@export var patrol_points: PackedVector3Array = PackedVector3Array()
@export var patrol_speed: float = 0.85
@export var hunt_speed: float = 1.25  # a brisk walk; the player always outpaces him
@export var follow_distance: float = 10.0
## When caught: reload the last checkpoint (off for tests that only want the signal).
@export var reload_on_catch: bool = true

const HISS := preload("res://assets/audio/sfx/tv_static.wav")
const LOSE_AFTER := 6.0

var state: State = State.ABSENT
## 0..1: how long the player has been held in his shot.
var exposure: float = 0.0
var last_seen: Vector3
var _patrol_index: int = 0
var _unseen_time: float = 0.0
var _search_left: int = 0
var _repath: float = 0.0
var _glitch_tick: float = 0.0
var _hiss: AudioStreamPlayer

@onready var body: NPC = get_parent() as NPC


func _ready() -> void:
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = HISS
	_hiss.bus = &"SFX"
	_hiss.volume_db = -60.0
	add_child(_hiss)
	_hiss.finished.connect(func() -> void:
		if exposure > 0.0:
			_hiss.play())
	body.look_at_player = false
	body.arrived.connect(_on_arrived)
	_set_state(State.ABSENT)


func _exit_tree() -> void:
	Graphics.set_dread(0.0)


## True if any stalker in the scene is currently patrolling/hunting (hint texts use it).
static func any_hunting(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group("stalkers"):
		if (node as Stalker).state in [State.PATROL, State.HUNT, State.SEARCH]:
			return true
	return false


func start_patrol(from_index: int = 0) -> void:
	_patrol_index = from_index % maxi(patrol_points.size(), 1)
	if not patrol_points.is_empty():
		body.global_position = patrol_points[_patrol_index]
	exposure = 0.0
	_set_state(State.PATROL)
	_next_patrol_point()


func follow() -> void:
	_set_state(State.FOLLOWING)


func stop() -> void:
	exposure = 0.0
	Graphics.set_dread(0.0)
	_set_state(State.ABSENT)


func _set_state(new_state: State) -> void:
	state = new_state
	if not is_in_group("stalkers"):
		add_to_group("stalkers")
	body.active = new_state not in [State.ABSENT]
	match new_state:
		State.PATROL, State.SEARCH:
			body.walk_speed = patrol_speed
		State.HUNT, State.FOLLOWING:
			body.walk_speed = hunt_speed
		_:
			body.stop()
	state_changed.emit(new_state)


func _physics_process(delta: float) -> void:
	if state in [State.ABSENT, State.CAUGHT, State.FINAL, State.FOOTAGE_ONLY, State.WATCHING]:
		_update_feedback(delta)
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if state == State.FOLLOWING:
		_follow(player, delta)
		return
	var sees := _in_shot(player)
	if sees:
		last_seen = player.global_position
		_unseen_time = 0.0
		var closeness := 1.0 - clampf(body.global_position.distance_to(player.global_position) / view_range, 0.0, 1.0)
		var seconds := lerpf(seconds_to_catch_far, seconds_to_catch_near, closeness)
		exposure = minf(exposure + delta / seconds, 1.0)
		if state != State.HUNT and exposure > 0.25:
			_set_state(State.HUNT)
		if state == State.HUNT:
			body.face(player.global_position)
			_repath -= delta
			if _repath <= 0.0:
				_repath = 0.5
				body.walk_to(last_seen)
		if exposure >= 1.0:
			_catch()
			return
	else:
		exposure = maxf(exposure - delta * 0.3, 0.0)
		_unseen_time += delta
		if state == State.HUNT and _unseen_time > LOSE_AFTER:
			_start_search()
	_update_feedback(delta)


## Is the player inside his camera's frame (angle, range, line of sight, not hiding)?
func _in_shot(player: Player) -> bool:
	if HidingSpot.is_hidden(player):
		return false
	var eye := body.global_position + Vector3(0, 1.62, 0)
	var target := player.global_position + Vector3(0, 1.2 if not player.is_crouching else 0.7, 0)
	var to := target - eye
	if to.length() > view_range:
		return false
	var forward := -body.global_transform.basis.z
	if rad_to_deg(Vector3(forward.x, 0, forward.z).angle_to(Vector3(to.x, 0, to.z))) > view_angle_deg:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _catch() -> void:
	_set_state(State.CAUGHT)
	caught.emit()
	get_tree().call_group("camcorder", "glitch", 1.0, 1.5)
	get_tree().call_group("camcorder", "show_static")
	get_tree().call_group("hud", "show_message", "TRACKING LOST", 2.0)
	if not reload_on_catch:
		return
	await get_tree().create_timer(2.0).timeout
	if not Game.load_checkpoint():
		Game.restart_chapter()


func _start_search() -> void:
	_set_state(State.SEARCH)
	_search_left = 3
	_search_step()


func _search_step() -> void:
	var a := randf() * TAU
	body.walk_to(last_seen + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 6.0))


func _on_arrived() -> void:
	match state:
		State.PATROL:
			_patrol_index = (_patrol_index + 1) % maxi(patrol_points.size(), 1)
			_next_patrol_point()
		State.SEARCH:
			_search_left -= 1
			if _search_left > 0:
				_search_step()
			else:
				_set_state(State.PATROL)
				_next_patrol_point()


func _next_patrol_point() -> void:
	if not patrol_points.is_empty():
		body.walk_to(patrol_points[_patrol_index])


## FOLLOWING: hold his distance behind the player; only move while they aren't looking.
func _follow(player: Player, _delta: float) -> void:
	var camera := player.camera
	var watched := camera.is_position_in_frustum(body.global_position + Vector3(0, 1.5, 0))
	if watched:
		body.stop()
		body.face(player.global_position)
		return
	var behind := player.global_position + player.global_transform.basis.z * follow_distance
	if body.global_position.distance_to(behind) > 2.0:
		body.walk_to(behind)


## Tracking errors + hiss rise with exposure (the camcorder's proximity warning).
func _update_feedback(delta: float) -> void:
	Graphics.set_dread(exposure)  # the picture narrows and drains of colour in his shot
	_hiss.volume_db = linear_to_db(clampf(exposure, 0.0001, 1.0)) - 6.0
	if exposure > 0.02 and not _hiss.playing:
		_hiss.play()
	elif exposure <= 0.0 and _hiss.playing:
		_hiss.stop()
	_glitch_tick -= delta
	if exposure > 0.05 and _glitch_tick <= 0.0:
		_glitch_tick = 0.25
		get_tree().call_group("camcorder", "glitch", exposure * 0.9, 0.3)
