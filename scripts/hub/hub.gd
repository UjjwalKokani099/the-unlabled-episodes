class_name Hub
extends Node3D
## Root of the hub room. Tracks the tape in the player's hand and runs the VCR:
## insert a tape -> clunk, blue screen "PLAY" -> Game.start_chapter(); with empty hands
## and a saved checkpoint -> resume it.

const PLAY_DELAY := 1.1

@export var tv: HubTV
@export var vcr: VCR

var held: HubTape = null
var busy: bool = false

var _hand: Node3D


func _ready() -> void:
	add_to_group("hub")
	_make_hand.call_deferred()
	if not Game.has_checkpoint() and not Game.is_completed(Game.chapter_list.chapters[0].id):
		_hint.call_deferred()


func pick_up(tape: HubTape) -> void:
	if busy or tape == held:
		return
	if held:
		held.put_back()
	held = tape
	tape.hold(_hand)


func vcr_prompt() -> String:
	if held:
		return "Insert " + held.display_name()
	if Game.has_checkpoint():
		var chapter := Game.get_chapter(Game.checkpoint_chapter_id())
		if chapter:
			return "Resume %s - %s" % [chapter.title, chapter.subtitle]
	return "VCR"


func use_vcr() -> void:
	if busy:
		return
	if held:
		var chapter := held.chapter
		if not chapter.is_built():
			get_tree().call_group("hud", "show_message", "The tape just hisses. (This tape isn't made yet.)")
			return
		_play(func() -> bool: return Game.start_chapter(chapter.id))
	elif Game.has_checkpoint():
		_play(func() -> bool: return Game.load_checkpoint())
	else:
		get_tree().call_group("hud", "show_message", "Take a tape from the shelf first.")


func _play(start: Callable) -> void:
	busy = true
	var player := _player()
	if player:
		player.input_enabled = false
	if held:
		held.visible = false  # it's in the VCR now
	vcr.insert_sound.play()
	tv.set_mode(HubTV.Mode.BLUE, "PLAY ►")
	await get_tree().create_timer(PLAY_DELAY).timeout
	if not start.call():
		# Couldn't start (shouldn't happen): give control back.
		busy = false
		tv.set_mode(HubTV.Mode.STATIC)
		if held:
			held.visible = true
		if player:
			player.input_enabled = true


func _make_hand() -> void:
	var player := _player()
	if player == null:
		return
	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = Vector3(0.3, -0.26, -0.5)
	player.camera.add_child(_hand)


func _hint() -> void:
	get_tree().call_group("hud", "show_message", "Take a tape from the shelf and play it in the VCR.", 5.0)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
