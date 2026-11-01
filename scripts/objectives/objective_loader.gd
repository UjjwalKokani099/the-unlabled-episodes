class_name ObjectiveLoader
extends Node
## Drop into a level to start its objectives when the level loads.

@export var objective_set: ObjectiveSet
## Clear remembered Events first, so a fresh run of the level starts clean.
@export var reset_events: bool = true


func _ready() -> void:
	# Deferred: lets every other node in the level finish _ready (and connect) first.
	_begin.call_deferred()


func _begin() -> void:
	if reset_events:
		Events.reset()
	if objective_set:
		Objectives.begin(objective_set)
