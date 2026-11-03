class_name Checkpoint
extends Area3D
## Saves progress when the player walks in, and is where they respawn after loading.
## Put the node's origin on the floor; the player respawns there facing the node's -Z.
## Give it a CollisionShape3D child (raised so it covers standing height).

@export var checkpoint_id: StringName


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Deferred to the end of the frame, so events fired by trigger zones entered in
		# the same physics step (e.g. a scare starting in the same doorway) are included.
		GameManager.save_checkpoint.call_deferred(checkpoint_id)
