class_name IdleEvents
extends Node
## Idle variety (studio spec 11): when the player has stood still (no walking, barely
## looking around) for `idle_seconds`, something small happens somewhere off-screen: a dog
## barks streets away, a pipe ticks, another building's watchman taps his stick. Never the
## same sound twice in a row; a pause of `cooldown` seconds between them; never while a
## scare, dialogue or cutscene holds saving, or while tension is high.
##
## Sounds come from `sounds`; each plays at a random spot `distance` metres away (behind or
## beside the player, never in plain view where nothing would be making it).

signal played(stream: AudioStream)

@export var sounds: Array[AudioStream] = []
@export var idle_seconds: float = 20.0
## Seconds between two idle sounds (random in this range).
@export var cooldown: Vector2 = Vector2(25.0, 45.0)
## How far away they play (random in this range, metres).
@export var distance: Vector2 = Vector2(14.0, 30.0)
@export var volume_db: float = -6.0
## Above this AudioManager tension the night is busy enough already.
@export var max_tension: float = 0.5

var idle_time: float = 0.0
var _wait: float = 0.0
var _last: AudioStream
var _last_pos: Vector3 = Vector3.INF
var _last_look: Vector3 = Vector3.ZERO


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or sounds.is_empty():
		return
	var pos := player.global_position
	var look := -player.camera.global_basis.z
	var moved := _last_pos != Vector3.INF and (pos.distance_to(_last_pos) > 0.02 or look.dot(_last_look) < 0.9995)
	_last_pos = pos
	_last_look = look
	if moved or not player.input_enabled:
		idle_time = 0.0
		return
	idle_time += delta
	_wait = maxf(_wait - delta, 0.0)
	if idle_time >= idle_seconds and _wait <= 0.0 and _quiet_moment():
		play_one(player)


## Plays one idle sound now (also used by tests). Returns it.
func play_one(player: Player) -> AudioStream:
	var pool := sounds.filter(func(s: AudioStream) -> bool: return s != _last or sounds.size() == 1)
	var stream: AudioStream = pool[randi() % pool.size()]
	_last = stream
	# somewhere beside or behind the player
	var back := player.camera.global_basis.z
	back.y = 0.0
	var dir := back.normalized().rotated(Vector3.UP, randf_range(-1.9, 1.9))
	var at := player.global_position + dir * randf_range(distance.x, distance.y) + Vector3(0, randf_range(1.0, 6.0), 0)
	AudioManager.play_at(stream, at, volume_db, 12.0)
	_wait = randf_range(cooldown.x, cooldown.y)
	played.emit(stream)
	return stream


func _quiet_moment() -> bool:
	return GameManager.can_save() and AudioManager.tension() <= max_tension and not AudioManager.is_silenced() \
		and not get_tree().paused
