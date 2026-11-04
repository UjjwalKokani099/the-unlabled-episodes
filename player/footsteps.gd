class_name Footsteps
extends Node
## The player's footsteps: one step per stride while walking on the floor, the sound picked
## by the surface underfoot (wood, carpet, tile, concrete, gravel, grass, metal; 5 variants
## each). Child of the Player; the head bob reads phase() so the camera dips on each step.
##
## Surface = `surface` metadata on the collision shape under the feet (tools/levelkit.py tags
## every kit collider from its material: tile, concrete, wood, metal, dirt, soft), or on the
## body itself for hand-built props. Unknown = concrete.
## Crouching = shorter, quieter steps; sprinting = longer, louder.

## Surface -> variant set (data/sounds/step_<surface>.tres, 5 clips each, never the same
## twice in a row, +-5% pitch).
const SOUND_SETS := {
	&"concrete": preload("res://data/sounds/step_concrete.tres"),
	&"tile": preload("res://data/sounds/step_tile.tres"),
	&"wood": preload("res://data/sounds/step_wood.tres"),
	&"metal": preload("res://data/sounds/step_metal.tres"),
	&"gravel": preload("res://data/sounds/step_gravel.tres"),
	&"grass": preload("res://data/sounds/step_grass.tres"),
	&"carpet": preload("res://data/sounds/step_carpet.tres"),
}
## Older surface names still found in some scenes.
const ALIASES := {&"dirt": &"gravel", &"soft": &"carpet"}
const DEFAULT_SURFACE := &"concrete"

## Metres per step.
@export var stride_walk: float = 0.72
@export var stride_crouch: float = 0.5
@export var stride_sprint: float = 0.95
@export var volume_walk_db: float = -9.0
@export var volume_crouch_db: float = -18.0
@export var volume_sprint_db: float = -4.0

signal stepped(surface: StringName)

## Surface of the last step (tests, and anything that wants to know).
var last_surface: StringName = &""
## Alternates every step (left/right), for the head bob's side sway.
var left_foot: bool = false
var steps_taken: int = 0
var _distance: float = 0.0
var _audio: AudioStreamPlayer

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"SFX"
	add_child(_audio)


func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_on_floor():
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < 0.3:
		# Standing still: the next step comes soon after moving off again.
		_distance = _stride() * 0.6
		return
	_distance += speed * delta
	if _distance >= _stride():
		_distance = 0.0
		step()


## Plays one step for the surface underfoot.
func step() -> void:
	last_surface = surface_under()
	steps_taken += 1
	left_foot = not left_foot
	var set: SoundSet = SOUND_SETS.get(last_surface, SOUND_SETS[DEFAULT_SURFACE])
	_audio.stream = set.pick()
	_audio.pitch_scale = set.random_pitch()
	if _player.is_crouching:
		_audio.volume_db = volume_crouch_db
	elif _player.is_sprinting:
		_audio.volume_db = volume_sprint_db
	else:
		_audio.volume_db = volume_walk_db
	_audio.play()
	stepped.emit(last_surface)


## Where the player is between two footfalls: 0 = the foot just landed, -> 1 = the next one.
## The head bob follows this, so the camera dips exactly when a step sounds.
func phase() -> float:
	return clampf(_distance / _stride(), 0.0, 1.0)


## Surface name of whatever is right under the player's feet.
func surface_under() -> StringName:
	var from := _player.global_position + Vector3(0, 0.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 0.6, 0), 1)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return DEFAULT_SURFACE
	var body := hit.collider as CollisionObject3D
	if body == null:
		return DEFAULT_SURFACE
	var owner_id := body.shape_find_owner(hit.shape)
	if owner_id >= 0:
		var shape_node := body.shape_owner_get_owner(owner_id) as Node
		if shape_node and shape_node.has_meta(&"surface"):
			return _canonical(StringName(shape_node.get_meta(&"surface")))
	if body.has_meta(&"surface"):
		return _canonical(StringName(body.get_meta(&"surface")))
	return DEFAULT_SURFACE


func _canonical(surface: StringName) -> StringName:
	return ALIASES.get(surface, surface)


func _stride() -> float:
	if _player.is_crouching:
		return stride_crouch
	if _player.is_sprinting:
		return stride_sprint
	return stride_walk
