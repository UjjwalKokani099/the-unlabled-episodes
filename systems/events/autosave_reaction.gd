class_name AutosaveReaction
extends EventReaction
## Autosave at a story beat: when `on_event` fires, save the checkpoint `checkpoint_id` (a
## Checkpoint area in the level: where the player respawns). Like every checkpoint it waits
## until no scare, dialogue, tape cut or chase holds saving.

@export var checkpoint_id: StringName = &"start"


func _ready() -> void:
	super._ready()
	save_hold_after = 0.0


func _react() -> void:
	GameManager.unblock_saving(self)  # an autosave must not wait for itself
	GameManager.save_checkpoint(checkpoint_id)
