class_name FlickerReaction
extends EventReaction
## Flickers lights (or any Node3D) for a while, irregularly (LightFlicker: value noise, with
## the tube's tick/buzz played on every drop-out). Lights flicker their brightness, so the
## player's own on/off (switches, the flashlight key) is left alone. Other nodes flicker their
## visibility.

enum EndState { RESTORE, ON, OFF }

@export var targets: Array[NodePath] = []
@export var duration: float = 1.2
## How targets end up. OFF = the light "dies" (hidden), ON = forced on.
@export var end_state: EndState = EndState.RESTORE
## Brightness multiplier during a drop-out (lights only).
@export var dim_factor: float = 0.04
## Drop-out sound (null = silent).
@export var sound: AudioStream = LightFlicker.SOUND

var is_flickering: bool = false


func _react() -> void:
	var nodes := _resolve(targets)
	var flickers: Array[LightFlicker] = []
	var original: Array = []  # visible, for nodes that aren't lights
	var played_sound := false
	for node in nodes:
		original.append((node as Node3D).visible)
		if node is Light3D:
			var f := LightFlicker.new(node as Light3D, dim_factor)
			# one light in a group makes the sound, the rest stay quiet (no stacking)
			f.sound = sound if not played_sound else null
			played_sound = true
			flickers.append(f)
		else:
			flickers.append(null)
	var shape := LightFlicker.new(null, 0.0)  # noise only, for visibility flicker
	is_flickering = true
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var dt := get_process_delta_time()
		elapsed += dt
		for i in nodes.size():
			if flickers[i]:
				flickers[i].step(dt)
			elif is_instance_valid(nodes[i]):
				(nodes[i] as Node3D).visible = bool(original[i]) and shape.level_at(elapsed) > 0.0

	for i in nodes.size():
		var node := nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		if flickers[i]:
			flickers[i].restore()
			if end_state != EndState.RESTORE:
				node.visible = end_state == EndState.ON
		else:
			node.visible = original[i] if end_state == EndState.RESTORE else end_state == EndState.ON
	is_flickering = false
