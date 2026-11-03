class_name SoundReaction
extends EventReaction
## Plays an AudioStreamPlayer / AudioStreamPlayer3D. Leave `player` empty to use the
## first audio player child (handy: put an AudioStreamPlayer3D under this node where
## the sound should come from).

@export var player: NodePath


func _react() -> void:
	var node: Node = get_node_or_null(player) if not player.is_empty() else _first_audio_child()
	if node and node.has_method(&"play"):
		node.call(&"play")
	else:
		push_warning("%s: no audio player to play" % get_path())


func _first_audio_child() -> Node:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			return child
	return null
