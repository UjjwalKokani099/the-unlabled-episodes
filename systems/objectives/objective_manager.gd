extends Node
## Tracks the current level's objectives, registered as the autoload "ObjectiveManager".
##
## React analogy: a reducer whose actions are Events ids. Load an ObjectiveSet with
## begin(); objectives become active once their `starts_after` objective is done, gain
## progress when their `complete_on` event fires, and when complete fire their own id
## as an event (so doors etc. can react, and later objectives can start).

signal started(objective: ObjectiveData)
signal progressed(objective: ObjectiveData, count: int)
signal completed(objective: ObjectiveData)
signal all_completed

var _all: Array[ObjectiveData] = []
var _active: Array[ObjectiveData] = []
var _progress: Dictionary = {}  # id -> int
var _done: Dictionary = {}  # id -> true
var _finished: bool = false


func _ready() -> void:
	EventBus.fired.connect(_on_event)


func begin(objective_set: ObjectiveSet) -> void:
	clear()
	_all = objective_set.objectives.duplicate()
	_start_ready_objectives()


func clear() -> void:
	_all.clear()
	_active.clear()
	_progress.clear()
	_done.clear()
	_finished = false


## Active objectives, in the order they appear in the set.
func get_active() -> Array[ObjectiveData]:
	var result: Array[ObjectiveData] = []
	for objective in _all:
		if objective in _active:
			result.append(objective)
	return result


func get_progress(id: StringName) -> int:
	return _progress.get(id, 0)


func is_active(id: StringName) -> bool:
	return _find(_active, id) != null


func is_completed(id: StringName) -> bool:
	return _done.has(id)


## Complete an objective from a script, regardless of its progress.
func complete(id: StringName) -> void:
	var objective := _find(_active, id)
	if objective:
		_complete(objective)


func _on_event(id: StringName) -> void:
	for objective in _active.duplicate():
		if objective in _active and objective.complete_on == id:
			_add_progress(objective, 1)


func _add_progress(objective: ObjectiveData, amount: int) -> void:
	var count := mini(get_progress(objective.id) + amount, objective.required)
	_progress[objective.id] = count
	progressed.emit(objective, count)
	if count >= objective.required:
		_complete(objective)


func _complete(objective: ObjectiveData) -> void:
	_active.erase(objective)
	_done[objective.id] = true
	completed.emit(objective)
	EventBus.objective_changed.emit(objective.id, true)
	EventBus.fire(objective.id)
	_start_ready_objectives()
	# (Completions can chain recursively; only announce the finish once.)
	if not _finished and _active.is_empty() and _done.size() == _all.size():
		_finished = true
		all_completed.emit()


func _start_ready_objectives() -> void:
	var newly_started: Array[ObjectiveData] = []
	for objective in _all:
		if objective in _active or _done.has(objective.id):
			continue
		if objective.starts_after == &"" or _done.has(objective.starts_after):
			_active.append(objective)
			_progress[objective.id] = 0
			newly_started.append(objective)
			started.emit(objective)
			EventBus.objective_changed.emit(objective.id, false)
	# Events that already happened count (e.g. batteries grabbed before the objective).
	for objective in newly_started:
		var past := EventBus.count(objective.complete_on)
		if past > 0 and objective in _active:
			_add_progress(objective, past)


func _find(list: Array[ObjectiveData], id: StringName) -> ObjectiveData:
	for objective in list:
		if objective.id == id:
			return objective
	return null
