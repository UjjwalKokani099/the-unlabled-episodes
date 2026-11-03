class_name AcousticZone
extends Area3D
## Room acoustics that follow the listener. While the player is inside, the "Space" reverb
## on the SFX bus (default_bus_layout.tres, effect 0) eases to this zone's preset, so
## footsteps, doors, voices and hums sound like the place you're standing in. Nested zones
## (the cabin inside the courtyard): the smallest one wins; outside every zone it's "open".
##
## No physics layer (it can never block the look ray or footstep ray); it only watches the
## player (layer 2). Generators place them: tools/levelkit.py acoustic_zone().

const BUS := &"SFX"
const PRESETS := {
	# room_size, damping, wet, predelay ms, spread
	&"open": [0.2, 0.8, 0.0, 20.0, 0.5],
	&"yard": [0.55, 0.55, 0.12, 70.0, 0.8],         # courtyard between tall walls: slap-back
	&"small_room": [0.22, 0.65, 0.14, 8.0, 0.5],    # furnished room: short, soft
	&"hard_room": [0.35, 0.3, 0.24, 12.0, 0.6],     # bare concrete (meter room, cabin)
	&"empty_room": [0.45, 0.25, 0.3, 18.0, 0.7],    # empty flat: echoey
	&"corridor": [0.45, 0.4, 0.2, 15.0, 0.6],
	&"stair": [0.78, 0.2, 0.34, 30.0, 0.8],         # concrete stairwell: long tail
}
const BLEND_SECONDS := 0.8

@export_enum("open", "yard", "small_room", "hard_room", "empty_room", "corridor", "stair") var space: String = "small_room"

static var _inside: Array[AcousticZone] = []
static var _tween: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the player
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			_inside.erase(self)
			_inside.append(self)
			_apply())
	body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			_inside.erase(self)
			_apply())


func _exit_tree() -> void:
	if self in _inside:
		_inside.erase(self)
		if _inside.is_empty():
			set_space(&"open", 0.0)


func _apply() -> void:
	set_space(current_space())


## Size of the zone (its first box shape), so the innermost of nested zones wins.
func volume() -> float:
	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((child as CollisionShape3D).shape as BoxShape3D).size
			return size.x * size.y * size.z
	return INF


## The reverb preset the player hears now (tests, debug).
static func current_space() -> StringName:
	var best: AcousticZone = null
	for zone in _inside:
		if is_instance_valid(zone) and (best == null or zone.volume() < best.volume()):
			best = zone
	return StringName(best.space) if best else &"open"


## Eases the SFX reverb to a preset over `seconds`.
static func set_space(preset: StringName, seconds: float = BLEND_SECONDS) -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var reverb := AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb
	if reverb == null:
		return
	var p: Array = PRESETS.get(preset, PRESETS[&"open"])
	if _tween and _tween.is_valid():
		_tween.kill()
	reverb.predelay_msec = p[3]
	reverb.spread = p[4]
	var tree := Engine.get_main_loop() as SceneTree
	if seconds <= 0.0 or tree == null:
		reverb.room_size = p[0]
		reverb.damping = p[1]
		reverb.wet = p[2]
		return
	_tween = tree.create_tween().set_parallel()
	_tween.tween_property(reverb, "room_size", p[0], seconds)
	_tween.tween_property(reverb, "damping", p[1], seconds)
	_tween.tween_property(reverb, "wet", p[2], seconds)
