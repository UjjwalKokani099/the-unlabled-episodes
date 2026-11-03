class_name ObjectiveLoader
extends Node
## Drop into a level to start its objectives when the level loads.
## Objectives rebuild their progress from Events counts, so after a checkpoint load
## (GameManager restores the counts first) they pick up exactly where the player was.

@export var objective_set: ObjectiveSet


func _ready() -> void:
	# Deferred: lets every other node in the level finish _ready (and connect) first.
	_begin.call_deferred()


func _begin() -> void:
	if objective_set == null:
		return
	EventBus.replaying = true  # re-completed objectives must not re-trigger scares
	ObjectiveManager.begin(objective_set)
	EventBus.replaying = false
