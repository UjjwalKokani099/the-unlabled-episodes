class_name Footsteps
extends Node
## The player's footsteps: one step per stride while walking on the floor, the sound picked
## by the surface underfoot. Child of the Player.
##
## Surface = `surface` metadata on the collision shape under the feet (tools/levelkit.py tags
## every kit collider from its material: tile, concrete, wood, metal, dirt, soft), or on the
## body itself for hand-built props. Unknown = concrete.
## Crouching = shorter, quieter steps; sprinting = longer, louder.

const SOUNDS := {
	&"concrete": preload("res://assets/audio/sfx/step_concrete.wav"),
	&"tile": preload("res://assets/audio/sfx/step_tile.wav"),
	&"wood": preload("res://assets/audio/sfx/step_wood.wav"),
	&"metal": preload("res://assets/audio/sfx/step_metal.wav"),
	&"dirt": preload("res://assets/audio/sfx/step_dirt.wav"),
	&"soft": preload("res://assets/audio/sfx/step_soft.wav"),
}
const DEFAULT_SURFACE := &"concrete"

## Metres per step.
@export var stride_walk: float = 0.72
@export var stride_crouch: float = 0.5
@export var stride_sprint: float = 0.95
@export var volume_walk_db: float = -9.0
@export var volume_crouch_db: float = -18.0
@export var volume_sprint_db: float = -4.0

## Surface of the last step (tests, and anything that wants to know).
var last_surface: StringName = &""
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
	_audio.stream = SOUNDS.get(last_surface, SOUNDS[DEFAULT_SURFACE])
	_audio.pitch_scale = randf_range(0.88, 1.12)
	if _player.is_crouching:
		_audio.volume_db = volume_crouch_db
	elif _player.is_sprinting:
		_audio.volume_db = volume_sprint_db
	else:
		_audio.volume_db = volume_walk_db
	_audio.play()


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
			return StringName(shape_node.get_meta(&"surface"))
	if body.has_meta(&"surface"):
		return StringName(body.get_meta(&"surface"))
	return DEFAULT_SURFACE


func _stride() -> float:
	if _player.is_crouching:
		return stride_crouch
	if _player.is_sprinting:
		return stride_sprint
	return stride_walk
