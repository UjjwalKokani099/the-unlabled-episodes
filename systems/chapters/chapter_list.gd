class_name ChapterList
extends Resource
## Every chapter in the game (res://data/chapter_list.tres).

## The tapes, in play order. Each unlocks when the previous one is completed.
@export var chapters: Array[ChapterData] = []
## Extra chapters for development (always unlocked, not part of progression).
@export var debug_chapters: Array[ChapterData] = []
## Where the player goes after finishing a tape. Empty = the project's main scene.
@export_file("*.tscn") var hub_scene: String
