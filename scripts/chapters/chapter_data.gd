class_name ChapterData
extends Resource
## One tape: what it's called, which level it loads, and when the camcorder clock starts.

## Saved in the save file, so don't rename once players have saves.
@export var id: StringName
## Big title on the tape card, e.g. "TAPE 01".
@export var title: String
## Line under it, e.g. "THE WATCHMAN".
@export var subtitle: String
## The level scene. Empty = not built yet (can't be started).
@export_file("*.tscn") var scene_path: String
## Camcorder date/time when the tape starts, "YYYY-MM-DDTHH:MM:SS".
## Empty = the player's real local time right now (the final tape is "tonight").
@export var start_datetime: String = "1998-10-31T23:42:00"


func is_built() -> bool:
	return scene_path != "" and ResourceLoader.exists(scene_path)
