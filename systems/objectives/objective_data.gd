class_name ObjectiveData
extends Resource
## One goal shown to the player, e.g. "Collect batteries 1/3".
## Lives inside an ObjectiveSet .tres file; no code needed per objective.

## Unique within the chapter. Fired as an Events id when the objective completes.
@export var id: StringName
## What the HUD shows.
@export var text: String
## Events id that counts toward this objective (each fire = +1).
@export var complete_on: StringName
## How many times `complete_on` must fire. Above 1 shows a counter.
@export_range(1, 99) var required: int = 1
## Objective id that must be completed first. Empty = active from the start.
@export var starts_after: StringName
