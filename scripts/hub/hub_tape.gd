class_name HubTape
extends Node3D
## One of the unlabeled tapes in Nikhil's box. The Hub hands the next one to the player
## (it moves into their hand) and the VCR plays it.

## Chapter id from chapters/chapter_list.tres.
@export var chapter_id: StringName
## Only show this tape in debug builds (the test tape).
@export var debug_only: bool = false

var chapter: ChapterData
var is_held: bool = false

var _home_parent: Node
var _home_transform: Transform3D

@onready var label: Label3D = $Label
@onready var watched_dot: Node3D = $WatchedDot
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if debug_only and not OS.is_debug_build():
		queue_free()
		return
	chapter = Game.get_chapter(chapter_id)
	_home_parent = get_parent()
	_home_transform = transform
	interactable.interacted.connect(_on_interacted)
	refresh()


func is_unlocked() -> bool:
	return chapter != null and Game.is_unlocked(chapter_id)


## Name for prompts, e.g. "TAPE 01 - THE WATCHMAN".
func display_name() -> String:
	if chapter == null:
		return "tape"
	return "%s - %s" % [chapter.title, chapter.subtitle] if chapter.subtitle != "" else chapter.title


func refresh() -> void:
	# The tapes are never labeled (story rule: a label is a name). Blank sticker, no marks.
	label.text = ""
	watched_dot.visible = false
	interactable.enabled = false  # tapes are taken through the box, not one by one


## Moves the tape into the player's hand (child of `hand`, a Node3D on the camera).
func hold(hand: Node3D) -> void:
	is_held = true
	interactable.enabled = false
	reparent(hand, false)
	transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-25), deg_to_rad(15), 0)), Vector3.ZERO)


## Puts it back where it came from on the shelf.
func put_back() -> void:
	is_held = false
	reparent(_home_parent, false)
	transform = _home_transform


func _on_interacted(_by: Node3D) -> void:
	if not is_unlocked():
		get_tree().call_group("hud", "show_message", "No label. You don't want to watch this one yet.")
		return
	var hub := get_tree().get_first_node_in_group("hub") as Hub
	if hub:
		hub.pick_up(self)
