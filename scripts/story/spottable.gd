class_name Spottable
extends Node3D
## One of the Cameraman's hidden appearances (story bible: three per tape, twelve in all).
## The player spots it by looking at it and pressing Spot (the camcorder's PAUSE button;
## see scripts/ui/camcorder.gd). Spotted ids are kept in the save (Game.mark_spotted).
##
## Put it where the player has to look: on the Cameraman himself, or on a CCTV monitor's
## screen with `monitor` + `monitor_camera` (then it only counts while that feed shows).

signal was_spotted

## Unique across the game, e.g. &"t1_cctv_stairs". Prefix = tape, for counting.
@export var spot_id: StringName
@export var max_distance: float = 30.0
## How far from the centre of the view it may be, in degrees.
@export var max_angle: float = 9.0
## Optional CCTVMonitor: only spottable while it shows camera `monitor_camera`.
@export var monitor: NodePath
@export var monitor_camera: int = -1

## Switched on/off by the level (an appearance only exists for a while).
@export var active: bool = true


func _ready() -> void:
	add_to_group("spottable")


## Degrees between the camera's view direction and this spot, or -1 if it can't be
## spotted from there (inactive, hidden, too far, off-centre or behind a wall).
func view_angle_from(camera: Camera3D) -> float:
	if not active or not is_visible_in_tree():
		return -1.0
	if not monitor.is_empty():
		var m := get_node_or_null(monitor) as CCTVMonitor
		if m == null or not m.is_live() or m.current != monitor_camera:
			return -1.0
	var from := camera.global_position
	var to := global_position
	var distance := from.distance_to(to)
	if distance > max_distance or distance < 0.05:
		return -1.0
	var forward := -camera.global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to((to - from) / distance))
	# A little more slack up close (a monitor fills more of the view).
	var allowed := max_angle + clampf(1.5 / distance, 0.0, 1.0) * 10.0
	if angle > allowed:
		return -1.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # world only
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and from.distance_to(hit.position) < distance - 0.4:
		return -1.0
	return angle


## Called by the camcorder when the player spots it.
func on_spotted() -> void:
	was_spotted.emit()
