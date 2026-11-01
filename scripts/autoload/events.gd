extends Node
## Global event bus, registered as the autoload "Events".
##
## React analogy: a tiny pub/sub store. Gameplay pieces announce what happened with a
## plain id, without knowing who listens:
##     Events.fire(&"vhs_tape")          # a pickup was taken
##     Events.fired.connect(_on_event)   # objectives, doors, scares... react
## Ids are free-form StringNames. Convention: item ids for pickups, objective ids when an
## objective completes, and descriptive names for everything else ("storage_opened").
## Counts are remembered until reset(), so late listeners can ask has_fired().

signal fired(id: StringName)

var _counts: Dictionary = {}  # StringName -> int


func fire(id: StringName) -> void:
	if id == &"":
		return
	_counts[id] = count(id) + 1
	fired.emit(id)


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func has_fired(id: StringName) -> bool:
	return count(id) > 0


## Forget everything (call when a chapter starts).
func reset() -> void:
	_counts.clear()
