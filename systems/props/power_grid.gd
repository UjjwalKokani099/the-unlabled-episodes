class_name PowerGrid
extends Node
## The building's mains power. A power cut switches off everything in the group "mains":
## nodes with set_power(on) get called (TubeLight, CCTVMonitor...), other Light3D nodes
## hide, AudioStreamPlayers (hums) stop. `glow_materials` (lit windows, lamp glass) lose
## their emission. Driven by Events, so it survives checkpoints:
##     cut_event fired more recently than restore_event -> the power is off.

signal power_changed(on: bool)

@export var cut_event: StringName = &"power_cut"
@export var restore_event: StringName = &"power_restored"
## Emissive materials that go dark in a cut (restored when the level closes).
@export var glow_materials: Array[BaseMaterial3D] = []

var powered: bool = true
var _glow: Dictionary = {}  # material -> original emission energy


func _ready() -> void:
	for mat in glow_materials:
		if mat:
			_glow[mat] = mat.emission_energy_multiplier
	EventBus.fired.connect(_on_event)
	# After a checkpoint load: off if the last thing that happened was a cut.
	if EventBus.count(cut_event) > EventBus.count(restore_event):
		_set_power.call_deferred(false)  # after every "mains" node is ready


func _exit_tree() -> void:
	# Materials are shared resources: leave them as they were for other levels.
	for mat: BaseMaterial3D in _glow:
		mat.emission_energy_multiplier = _glow[mat]


func cut() -> void:
	_set_power(false)


func restore() -> void:
	_set_power(true)


func _on_event(id: StringName) -> void:
	if id == cut_event:
		cut()
	elif id == restore_event:
		restore()


func _set_power(on: bool) -> void:
	if on == powered:
		return
	powered = on
	for node in get_tree().get_nodes_in_group("mains"):
		if node.has_method(&"set_power"):
			node.set_power(on)
		elif node is Light3D:
			(node as Light3D).visible = on
		elif node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			if on:
				node.play()
			else:
				node.stop()
	for mat: BaseMaterial3D in _glow:
		mat.emission_energy_multiplier = _glow[mat] if on else 0.0
	power_changed.emit(on)
