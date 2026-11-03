extends Node3D
## Night ambience: looping beds (child AudioStreamPlayers with "loop" in their name restart
## when finished) plus random one-shots (children of $OneShots, AudioStreamPlayer3D) played
## every few seconds from random spots around `radius` metres.

@export var min_gap: float = 6.0
@export var max_gap: float = 18.0
@export var radius: float = 40.0

var _timer: float = 3.0


func _ready() -> void:
	for child in get_children():
		if child is AudioStreamPlayer and String(child.name).to_lower().contains("loop"):
			child.finished.connect(child.play)
			child.play()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or not has_node("OneShots"):
		return
	_timer = randf_range(min_gap, max_gap)
	var shots := $OneShots.get_children()
	if shots.is_empty():
		return
	var player := shots.pick_random() as AudioStreamPlayer3D
	var a := randf() * TAU
	player.position = Vector3(cos(a), 0.3, sin(a)) * radius
	player.play()
