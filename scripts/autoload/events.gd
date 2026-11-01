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

## True while a checkpoint load rebuilds state (objectives re-completing etc.).
## Scares (EventReaction) ignore events fired while this is set.
var replaying: bool = false

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


## Forget everything (Game calls this when a chapter starts).
func reset() -> void:
	_counts.clear()


## Plain copy of the counts, for save files.
func snapshot() -> Dictionary:
	var copy := {}
	for id: StringName in _counts:
		copy[String(id)] = _counts[id]
	return copy


## Replace the counts with a saved snapshot (emits nothing).
func restore(saved: Dictionary) -> void:
	_counts.clear()
	for key: String in saved:
		_counts[StringName(key)] = int(saved[key])
