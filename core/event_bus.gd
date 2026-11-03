extends Node
## Global event bus, registered as the autoload "EventBus".
##
## React analogy: a tiny pub/sub store. Gameplay pieces announce what happened with a
## plain id, without knowing who listens:
##     EventBus.fire(&"vhs_tape")          # a pickup was taken
##     EventBus.fired.connect(_on_event)   # objectives, doors, scares... react
## Ids are free-form StringNames. Convention: item ids for pickups, objective ids when an
## objective completes, and descriptive names for everything else ("storage_opened").
## Counts are remembered until reset(), so late listeners can ask has_fired().

## Story / gameplay happenings by id (data-driven: objectives, reactions, scripts).
signal fired(id: StringName)

# Typed system signals: systems announce lifecycle changes here instead of holding
# references to each other.
signal chapter_started(chapter: ChapterData)
signal chapter_completed(chapter: ChapterData)
signal checkpoint_saved(checkpoint_id: StringName)
signal scene_transition_started(path: String)
signal scene_transition_finished(path: String)
signal setting_changed(key: StringName)
signal input_device_changed(device: int)
signal objective_changed(objective_id: StringName, completed: bool)
signal game_paused(paused: bool)

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


## Forget everything (GameManager calls this when a chapter starts).
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
