class_name EventReaction
extends Node
## Base for "when Events id X fires, do something". Subclasses override _react().
##
## React analogy: a useEffect that runs when a specific event happens. Stack several
## reactions on the same event (each with its own delay) to choreograph a scare.

## Events id to react to.
@export var on_event: StringName
## Seconds to wait after the event before reacting (pauses with the game).
@export var delay: float = 0.0
## React only the first time the event fires.
@export var once: bool = true

var _has_reacted: bool = false


func _ready() -> void:
	EventBus.fired.connect(_on_event)
	tree_exiting.connect(func() -> void: GameManager.unblock_saving(self))


## Seconds after reacting during which saving stays held (a scare plays out).
@export var save_hold_after: float = 2.5


## Run the reaction now, ignoring on_event and delay.
func trigger() -> void:
	_react()


func _on_event(id: StringName) -> void:
	if id != on_event or (once and _has_reacted) or EventBus.replaying:
		return
	_has_reacted = true
	# Never save mid-scare: hold saving from the event until this reaction has played out.
	GameManager.block_saving(self, delay + save_hold_after + 30.0)
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
		if not is_inside_tree():
			GameManager.unblock_saving(self)
			return
	_react()
	if save_hold_after > 0.0:
		GameManager.block_saving(self, save_hold_after)
	else:
		GameManager.unblock_saving(self)


## Override in subclasses.
func _react() -> void:
	pass


## Resolves an array of NodePaths (relative to this node), skipping missing ones.
func _resolve(paths: Array[NodePath]) -> Array[Node]:
	var nodes: Array[Node] = []
	for path in paths:
		var node := get_node_or_null(path)
		if node:
			nodes.append(node)
		else:
			push_warning("%s: no node at %s" % [get_path(), path])
	return nodes
