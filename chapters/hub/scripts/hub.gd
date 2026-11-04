class_name Hub
extends Node3D
## Nikhil's room between tapes (story bible: The Hub).
##
## - The cardboard box hands Nikhil the next unwatched tape; the VCR plays it (or resumes a
##   saved checkpoint when his hands are empty).
## - Evening chores are optional objectives: eat dinner, reply to Maa, charge the phone.
## - Nikhil's phone (PlayerPhone, data/phone/hub.json) lies on the desk: take it, raise it (R),
##   reply to Maa in Messages; the charger takes it and gives it back. Texts and calls arrive
##   by hub stage (a missed call at 3:12 from stage 2, Maa calling at stage 2).
## - The room changes after each tape (stage = tapes watched, in order):
##     1: a diary entry in someone else's handwriting   2: a white van idles in the lane
##     3: "108" scratched inside his door               4: doorbell + delivery bag outside;
##                                                         the box now holds a fifth tape
## debug_stage (or F6 in debug builds) previews any stage.

const PLAY_DELAY := 1.1
const TAPE_SCENE := preload("res://chapters/hub/hub_tape.tscn")
const DOORBELL := preload("res://assets/audio/sfx/doorbell.wav")
## Nikhil's thoughts on coming back to the room after each tape (stage = tapes watched).
## Present tense, quiet: he's alive, for now. Each plays once (GameManager flag).
const ARRIVAL_THOUGHTS := {
	0: ["Four tapes, a hundred and fifty rupees. The man didn't even look up when I paid.", 5.0],
	1: ["A watchman. Some housing society in '98. Whoever filmed that never stopped the camera.", 5.0],
	2: ["The van in that tape was white too. Same as... no. Lots of white vans.", 5.0],
	3: ["Room 108. Why do I know that number?", 4.0],
	4: ["Every address on that wall was crossed out. Except the last one.", 5.0],
}
const SPEAKER := "NIKHIL"
const PHONE_DATA := "res://data/phone/hub.json"

## -1 = from the save file. 0..4 = force a stage (testing / previews).
@export var debug_stage: int = -1

var stage: int = 0
var held: HubTape = null
var busy: bool = false
var room: Node3D
var tv: HubTV
var vcr: VCR

var _hand: Node3D
var _box_tapes: Array[HubTape] = []
var _scratch: Label3D
var _doorbell_rung: bool = false
var phone: PlayerPhone


func _ready() -> void:
	add_to_group("hub")
	room = $Room
	tv = room.get_node("TV")
	vcr = room.get_node("VCR")
	_connect(room.get_node("TapeBox/Interactable"), use_box)
	_connect(room.get_node("Diary/Interactable"), read_diary)
	_connect(room.get_node("Plate/Interactable"), eat_dinner)
	_connect(room.get_node("Phone/Interactable"), take_phone)
	_connect(room.get_node("Charger/Interactable"), charge_phone)
	_connect(room.get_node("DeliveryBag/Interactable"), read_bill)
	stage = compute_stage() if debug_stage < 0 else debug_stage
	apply_stage()
	_make_hand.call_deferred()
	_setup_phone.call_deferred()
	_start_chores.call_deferred()
	_arrival_thought()


## Number of tapes watched, counting in order.
func compute_stage() -> int:
	var count := 0
	for chapter in GameManager.chapter_list.chapters:
		if not GameManager.is_completed(chapter.id):
			break
		count += 1
	return count


func apply_stage() -> void:
	_fill_box()
	(room.get_node("Van") as Node3D).visible = stage >= 2
	(room.get_node("DeliveryBag") as Node3D).visible = stage >= 4
	if stage >= 3 and _scratch == null:
		_scratch = Label3D.new()
		_scratch.text = "108"
		_scratch.font_size = 96
		_scratch.pixel_size = 0.002
		_scratch.shaded = true
		_scratch.modulate = Color(0.85, 0.78, 0.68)
		_scratch.outline_size = 0
		var hinge: Node3D = room.get_node("Door/Hinge")
		hinge.add_child(_scratch)
		_scratch.position = Vector3(0.55, 1.55, -0.03)
		_scratch.rotation.y = PI
	elif stage < 3 and _scratch:
		_scratch.queue_free()
		_scratch = null
	if stage >= 4 and not _doorbell_rung:
		_doorbell_rung = true
		_ring_doorbell.call_deferred()


# --- Tapes -------------------------------------------------------------------

func next_chapter() -> ChapterData:
	for chapter in GameManager.chapter_list.chapters:
		if GameManager.is_unlocked(chapter.id) and not GameManager.is_completed(chapter.id):
			return chapter
	return null


func box_prompt() -> String:
	if held:
		return "Put the tape back"
	return "Take the next tape" if next_chapter() else "The box of tapes"


func use_box() -> void:
	if busy:
		return
	if held:
		held.put_back()
		held = null
		return
	var chapter := next_chapter()
	if chapter == null:
		_message("You've watched every tape in the box.")
		return
	for tape in _box_tapes:
		if tape.chapter_id == chapter.id:
			pick_up(tape)
			return


func pick_up(tape: HubTape) -> void:
	if busy or tape == held:
		return
	if held:
		held.put_back()
	held = tape
	tape.hold(_hand)


func vcr_prompt() -> String:
	if held:
		return "Play the tape"
	if GameManager.has_checkpoint():
		return "Resume the tape"
	return "VCR"


func use_vcr() -> void:
	if busy:
		return
	if held:
		var chapter := held.chapter
		if chapter == null or not chapter.is_built():
			_demo_end()
			return
		EventBus.fire(&"tape_inserted")
		_play(func() -> bool: return GameManager.start_chapter(chapter.id))
	elif GameManager.has_checkpoint():
		EventBus.fire(&"tape_inserted")
		_play(func() -> bool: return GameManager.load_checkpoint())
	else:
		_message("Take a tape from the box first.")


func _play(start: Callable) -> void:
	busy = true
	var player := _player()
	if player:
		player.input_enabled = false
	if held:
		held.visible = false
	vcr.insert_sound.play()
	tv.set_mode(HubTV.Mode.BLUE, "PLAY ►")
	await get_tree().create_timer(PLAY_DELAY).timeout
	if not start.call():
		busy = false
		tv.set_mode(HubTV.Mode.STATIC)
		if held:
			held.visible = true
		if player:
			player.input_enabled = true


## The demo stops at the first tape that isn't built: the VCR takes it, the TV shows PLAY,
## then static, then the end-of-demo card (ui/menus/demo_end.gd).
func _demo_end() -> void:
	busy = true
	var player := _player()
	if player:
		player.input_enabled = false
	vcr.insert_sound.play()
	tv.set_mode(HubTV.Mode.BLUE, "PLAY ►")
	await get_tree().create_timer(PLAY_DELAY).timeout
	tv.set_mode(HubTV.Mode.STATIC)
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree():
		return
	var card := DemoEnd.new()
	card.name = "DemoEnd"
	add_child(card)
	await card.closed
	if player:
		player.input_enabled = true
	busy = false
	_think_once(&"demo_end", "Same as the first one. No label. Just... waiting.", 4.0, 1.0)


func _fill_box() -> void:
	for tape in _box_tapes:
		if tape != held:
			tape.get_parent().remove_child(tape)  # detach now so names are free for the new ones
			tape.queue_free()
	_box_tapes.clear()
	var count := 4 + (1 if stage >= 4 else 0)  # he bought four; the fifth just appears
	var slots: Node3D = room.get_node("TapeBox/Slots")
	var chapters := GameManager.chapter_list.chapters
	for i in mini(count, chapters.size()):
		var tape: HubTape = TAPE_SCENE.instantiate()
		tape.chapter_id = chapters[i].id
		slots.add_child(tape)
		tape.position = Vector3(0, 0.02, -0.11 + i * 0.05)
		_box_tapes.append(tape)
	if OS.is_debug_build():  # the grey test tape, lying on the desk
		var test: HubTape = TAPE_SCENE.instantiate()
		test.chapter_id = &"tape_00_test"
		test.name = "TestTape"
		room.add_child(test)
		test.position = Vector3(3.05, 0.76, 2.2)
		test.rotation.x = -PI / 2
		test.interactable.enabled = true
		test.interactable.prompt = "Take the test tape"
		test.interactable.interacted.connect(func(_by: Node3D) -> void: pick_up(test))
		_box_tapes.append(test)


# --- Chores and story objects --------------------------------------------------

func read_diary() -> void:
	var text := "[b]Sunday[/b]\nSunday market near the old bus depot. Bought a box of VHS tapes for 150 rupees. Four tapes. No labels on any of them.\n\n[b]Monday[/b]\nWork till late. Maa called twice. Need to fix the VCR tracking.\n"
	if stage >= 1:
		var d := Time.get_date_dict_from_system()
		text += "\n[color=#5a1a10][i]%02d/%02d/%d  —  3:12 AM, out.[/i][/color]" % [d.day, d.month, d.year]
	get_tree().call_group("hud", "show_note", text, true)
	if stage >= 1:
		EventBus.fire(&"read_strange_entry")
		_think_once(&"diary_entry", "...That's not my handwriting.", 3.5, 1.0)


func eat_dinner() -> void:
	var plate := room.get_node("Plate")
	if not (plate.get_node("Food") as Node3D).visible:
		_message("Just the plate now.")
		return
	(plate.get_node("Food") as Node3D).visible = false
	(plate.get_node("Interactable") as Interactable).prompt = "Empty plate"
	_message("Dal-chawal. Already cold.")
	_think_once(&"dinner", "Maa would say I eat like a hostel boy. She'd be right.", 4.0, 2.8)
	EventBus.fire(&"ate_dinner")


func _setup_phone() -> void:
	var player := _player()
	if player == null:
		return
	phone = PlayerPhone.attach(player, PHONE_DATA, stage)
	phone.desk_anchor = room.get_node("Phone")
	# After every tape the battery is nearly flat, though he charged it (the tape ran on it).
	if stage >= 1 and GameManager.remember("hub_phone_drained_%d" % stage):
		phone.screen.battery = 0.12
	(room.get_node("Phone/Interactable") as Interactable).prompt = "Take your phone"


## Pick the phone up from the desk (or off the charger).
func take_phone() -> void:
	if phone == null:
		return
	var prop := room.get_node("Phone") as Node3D
	prop.visible = false
	(prop.get_node("Interactable") as Interactable).enabled = false
	phone.carried = true
	phone.charging = false
	phone.desk_anchor = prop
	(room.get_node("Charger/Interactable") as Interactable).enabled = true
	EventBus.fire(&"took_phone")
	if GameManager.remember("hub_phone_hint"):
		_message("Your phone. [%s] to look at it." % SettingsManager.key_name(&"phone"), 4.0)


func charge_phone() -> void:
	if phone == null or not phone.carried:
		_message("Your phone is on the desk.")
		return
	var prop := room.get_node("Phone") as Node3D
	prop.global_position = (room.get_node("ChargingSpot") as Node3D).global_position
	prop.visible = true
	(prop.get_node("Interactable") as Interactable).enabled = true
	(room.get_node("Charger/Interactable") as Interactable).enabled = false
	phone.carried = false
	phone.charging = true
	_message("Phone charging. %d%%." % roundi(phone.screen.battery * 100.0))
	if stage >= 1:
		_think_once(&"charging_late", "Twelve percent. I charged it this morning. Did I fall asleep with the tape running?", 5.0, 2.8)
	EventBus.fire(&"phone_charging")


func read_bill() -> void:
	var d := Time.get_date_dict_from_system()
	get_tree().call_group("hud", "show_note",
		"[b]FOODRUN[/b]   Order #3112\n%02d/%02d/%d   12:50 AM\n\n1 x Veg Thali\n1 x Gulab Jamun (2 pc)\n\n[b]Deliver to:[/b] Nikhil\nRoom 3, 2nd floor, Sai Krupa Building\nLane 4, behind the old bus depot\n\nPaid.   [i]Status: DELIVERED[/i]" % [d.day, d.month, d.year])
	EventBus.fire(&"read_bill")


func _start_chores() -> void:
	var set := ObjectiveSet.new()
	for spec in [[&"eat", "Eat dinner", &"ate_dinner"], [&"maa", "Reply to Maa", &"replied_maa"],
			[&"charge", "Charge your phone", &"phone_charging"]]:
		var o := ObjectiveData.new()
		o.id = spec[0]
		o.text = spec[1]
		o.complete_on = spec[2]
		set.objectives.append(o)
	var watch := ObjectiveData.new()
	watch.id = &"watch"
	watch.text = "Watch the next tape" if next_chapter() else "Nothing left to watch"
	watch.complete_on = &"tape_inserted"
	set.objectives.append(watch)
	ObjectiveManager.begin(set)
	if stage == 0 and not GameManager.has_checkpoint():
		_message("Take a tape from the box and play it in the VCR.", 5.0)


func _ring_doorbell() -> void:
	await get_tree().create_timer(6.0).timeout
	if not is_inside_tree():
		return
	var bell := AudioStreamPlayer3D.new()
	bell.stream = DOORBELL
	bell.bus = &"SFX"
	room.get_node("Door").add_child(bell)
	bell.position = Vector3(0.5, 1.8, 0.5)
	bell.play()
	_message("The doorbell.")
	_think_once(&"doorbell", "It's almost one. I didn't order anything.", 3.5, 2.6)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.physical_keycode == KEY_F6:
		stage = (stage + 1) % 5
		_doorbell_rung = stage < 4
		apply_stage()
		_message("Debug: hub stage %d (tapes watched)" % stage)


# --- Helpers ---------------------------------------------------------------------

func _arrival_thought() -> void:
	if not ARRIVAL_THOUGHTS.has(stage) or (stage == 0 and GameManager.has_checkpoint()):
		return
	var line: Array = ARRIVAL_THOUGHTS[stage]
	_think_once(StringName("arrival_%d" % stage), line[0], line[1], 3.0)


## A thought (subtitle, speaker NIKHIL) that plays once per save, `delay` seconds from now.
## Uses GameManager.remember (the save file): chapter flags are wiped whenever the hub loads.
func _think_once(key: StringName, text: String, seconds: float, delay: float = 0.0) -> void:
	if not GameManager.remember("hub_thought_" + String(key)):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	get_tree().call_group("subtitles", "think", text, seconds)  # inner monologue


func _connect(area: Interactable, method: Callable) -> void:
	area.interacted.connect(func(_by: Node3D) -> void: method.call())


func _message(text: String, seconds: float = 2.5) -> void:
	get_tree().call_group("hud", "show_message", text, seconds)


func _make_hand() -> void:
	var player := _player()
	if player == null:
		return
	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = Vector3(0.3, -0.26, -0.5)
	player.camera.add_child(_hand)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
