class_name HidingSpot
extends Area3D
## A place to hide from the Cameraman: crouch inside it (behind a parked car, between
## pillars) and his camera can't hold you in frame. Give it a CollisionShape3D child.
## Stalker asks HidingSpot.is_hidden(player).

## Shown once each time the player steps in without crouching.
@export var hint: String = "Crouch to hide."

var _player_inside: bool = false


func _ready() -> void:
	add_to_group("hiding_spots")
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = true
			if not (body as Player).is_crouching and hint != "" and Stalker.any_hunting(get_tree()):
				get_tree().call_group("hud", "show_message", hint, 2.0))
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = false)


func contains_player() -> bool:
	return _player_inside


## True if the player is crouched inside any hiding spot.
static func is_hidden(player: Player) -> bool:
	if player == null or not player.is_crouching:
		return false
	for node in player.get_tree().get_nodes_in_group("hiding_spots"):
		var spot := node as HidingSpot
		if spot.contains_player() or spot.overlaps_body(player):
			return true
	return false
