extends Node
## Tape 1 story director (story bible, "The Watchman"): everything after Raghu's first
## round. Listens to Events and drives the scripted beats; objectives (objectives.tres)
## tell the player what to do next. Pacing: ~70% duties, ~20% wrongness, ~10% ending.
##
##   (first round)      -> Mr. Deshmukh waits under B wing and asks for the gate at 3:12;
##                         Mrs. Iyer (2C) walks over for her parcel after the CCTV check
##   back_at_cabin      -> tape cut, the clock jumps to 3:10 AM
##   register_3am       -> Mr. Deshmukh walks out of the gate (3:12), never comes back
##   deshmukh_left      -> on the CCTV he stands on his 4B balcony; the real one is empty
##   balcony_checked    -> the 4B intercom rings: only breathing
##   4b_checked         -> 4B is empty, dust sheets, the handset off the hook
##   register_read_late -> entries in someone else's hand log Raghu's movements
##   phone_used         -> the secretary: "4B has been empty for eight months" -> power cut
##   main_switch        -> lights back; the last CCTV frame: a red dot behind him. Static.
##
## Everything it sets up is derived from Events counts in _restore(), so checkpoints work.
## Node names are the ones tools/gen_tape01.py writes.

const VO := "RAGHU (V.O.)"
const RAGHU := "RAGHU"
const SECRETARY := "SECRETARY"
const CUT_TO := "03:10:40"
const OPENING := [
	["My name was Raghu. In March of '98, I took the night shift at Shanti Vihar.", 5.0],
	["The old watchman, Kishan, had stopped coming. Nobody told me why.", 4.5],
	["Four buildings, one gate, one register. It was supposed to be easy work.", 4.5],
]
const SFX := "res://assets/audio/sfx/"
const SECRETARY_DIALOGUE := "res://dialogue/tape01/secretary.json"
## Mrs. Iyer: C wing entrance <-> outside the cabin door.
const IYER_HOME := Vector3(3.5, 0, -13.2)
const IYER_WAIT := Vector3(3.3, 0, 23.4)
## Mr. Deshmukh goes back into the B wing stairwell after talking.
const DESHMUKH_STAIRS := Vector3(-12.5, 0, -14.9)

## Multiplies every scripted wait (tests make it small).
var time_scale: float = 1.0
var ending_started: bool = false
var _calling: bool = false
var _sfx: AudioStreamPlayer
var _deshmukh_called: bool = false

@onready var level: Node = get_parent()
@onready var cctv: CCTVMonitor = level.get_node("CCTV")
@onready var power: PowerGrid = level.get_node("Power")
@onready var wicket: Node3D = level.get_node("Wicket")
@onready var deshmukh: NPCWalker = level.get_node("Deshmukh")
@onready var balcony: Node3D = level.get_node("BalconyDeshmukh")
@onready var cam_stairs: Cameraman = level.get_node("CamStairs")
@onready var spot_cctv: Spottable = level.get_node("SpotCCTV")
@onready var cam_4b: Cameraman = level.get_node("Cam4B")
@onready var cam_window: Cameraman = level.get_node("CamWindowD")
@onready var stalker: Stalker = level.get_node("Stalker/Brain")
@onready var stool: Node3D = level.get_node("Stool")
@onready var cam_ending: Cameraman = level.get_node("CamEnding")
@onready var raghu: Node3D = level.get_node("RaghuStandIn")
@onready var main_switch: Interactable = level.get_node("MainSwitch/Interactable")
@onready var intercom_breath: AudioStreamPlayer3D = level.get_node("Intercom/Breath")
@onready var flat_breath: AudioStreamPlayer3D = level.get_node("FlatBreath")
@onready var fan: AudioStreamPlayer3D = level.get_node("CabinFan")
@onready var deshmukh_npc: NPC = level.get_node("DeshmukhNPC")
@onready var iyer: NPC = level.get_node("IyerNPC")


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	add_child(_sfx)
	fan.finished.connect(func() -> void:
		if power.powered:
			fan.play())
	Events.fired.connect(_on_event)
	_restore()
	if Game.get_flag("t1_opening") == null and not Events.has_fired(&"register_signed"):
		Game.set_flag("t1_opening", true)
		_opening()


func _restore() -> void:
	var left := Events.has_fired(&"deshmukh_left")
	balcony.visible = left
	if left:
		cctv.use_message = ""
	cam_stairs.active = left and not Events.has_fired(&"4b_checked")
	spot_cctv.active = cam_stairs.active
	cam_4b.active = Events.has_fired(&"intercom_answered") and not Events.has_fired(&"cabin_return2")
	var dark := Events.count(&"power_cut") > Events.count(&"power_restored")
	cam_window.active = Events.has_fired(&"check_cctv") and not Events.has_fired(&"back_at_cabin")
	if Events.has_fired(&"back_at_cabin"):
		_move_stool()
	if dark and not Events.has_fired(&"meter_room_reached"):
		stalker.start_patrol.call_deferred()
	main_switch.enabled = dark
	if Events.has_fired(&"register_3am") and not left:
		_after(3.0, func() -> void: Events.fire(&"deshmukh_walk"))
	# People of the first round.
	var night := Events.has_fired(&"back_at_cabin")
	deshmukh_npc.active = not night and Game.get_flag("t1_deshmukh_gone", null) == null
	iyer.active = not night and Events.has_fired(&"check_cctv") and Game.get_flag("t1_iyer_home", null) == null
	if iyer.active:
		iyer.global_position = IYER_WAIT
		_iyer_waits()


## Raghu's narration, calm and in the past tense (story bible: the narrator is already
## dead). Each line plays once per playthrough: a Game flag survives checkpoint reloads.
const VO_BEATS := {
	&"register_signed": [6.0, "I wrote my name in the register. Raghu, ten-forty PM. Neat letters. My father taught me that.", 5.0],
	&"kishan_card": [0.8, "Someone had cut his face out of it. I told myself it was the society children.", 4.5],
	&"talked_deshmukh": [1.5, "He knew my name before I said it. Old men in old buildings know everything. That's what I told myself.", 5.5],
	&"lock_terraces": [1.0, "Four terraces, four padlocks. I counted the keys twice. I don't know why.", 4.5],
	&"balcony_checked": [5.0, "I stood under that balcony a long time. Long enough to feel foolish. Not long enough to leave.", 5.0],
	&"4b_checked": [10.0, "Eight months of dust. And a clock on the wall, stopped at twelve minutes past three.", 5.0],
	&"register_read_late": [4.5, "Every place I had been that night, someone had written it down. To the minute.", 4.5],
	&"meter_room_reached": [1.0, "I didn't look behind me. I have thought about that a lot, since.", 4.5],
}


func _on_event(id: StringName) -> void:
	if Events.replaying or ending_started:
		return
	if VO_BEATS.has(id) and Game.get_flag("t1_vo_" + String(id)) == null:
		Game.set_flag("t1_vo_" + String(id), true)
		var beat: Array = VO_BEATS[id]
		_after(beat[0], _say.bind(VO, beat[1], beat[2]))
	match id:
		&"back_at_cabin":
			deshmukh_npc.active = false
			iyer.active = false
			cam_window.active = false
			if Objectives.is_active(&"give_parcel"):
				Objectives.complete(&"give_parcel")  # she gave up and went to bed
			_cut_to_three()
		&"check_cctv":
			_iyer_comes_down()
			cam_window.active = true
		&"talked_iyer":
			if Events.has_fired(&"parcel_given"):
				_iyer_goes_home()
		&"talked_deshmukh":
			_deshmukh_goes_in()
		&"register_3am":
			_after(5.0, func() -> void: Events.fire(&"deshmukh_walk"))
		&"deshmukh_at_gate":
			_wicket(true)
			if Dialogue.flag("promised_gate"):
				_say(RAGHU, "Going out, sahab? I kept it open, like you asked.", 3.5)
			elif Dialogue.flag("refused_gate"):
				_say(RAGHU, "Sahab, the gate stays locked after—", 2.5)
				_after(2.0, _message.bind("The little gate swings open by itself.", 3.0))
			else:
				_say(RAGHU, "Deshmukh-ji? Sahab... at this hour?", 3.5)
		&"deshmukh_left":
			_after(1.2, _wicket.bind(false))
			balcony.visible = true
			cctv.use_message = ""
			cam_stairs.active = true
			spot_cctv.active = true
			_after(4.0, _say.bind(VO, "He didn't answer. He didn't even look at me.", 4.0))
		&"cctv_checked":
			if Events.has_fired(&"deshmukh_left"):
				cctv.show_camera(1, 3.0)
				if Objectives.is_active(&"cctv_again"):
					_message("CAM 2. Someone on the 4B balcony... Deshmukh-ji?", 4.0)
					_after(2.5, func() -> void: Events.fire(&"cctv_deshmukh"))
				else:
					_message("CAM 2. He's still there. Watching the gate.", 3.5)
		&"balcony_checked":
			_note_time(id)
			_message("Nobody. The balcony door is shut. No light inside.", 4.0)
			_after(4.0, func() -> void: Events.fire(&"intercom_ring"))
		&"intercom_answered":
			_note_time(id)
			_intercom_call()
		&"4b_checked":
			_note_time(id)
			cam_stairs.active = false
			spot_cctv.active = false
			_message("Nobody. Dust sheets over everything.", 4.0)
			_after(5.0, func() -> void:
				flat_breath.play()
				_message("The intercom handset is hanging off its hook.", 4.0))
		&"cabin_return2":
			_note_time(id)
			cam_4b.active = false
		&"register_read_late":
			_after(0.4, _say.bind(RAGHU, "...That's not my handwriting.", 3.5))
		&"phone_used":
			if Objectives.is_active(&"call_secretary"):
				if not _calling:
					_secretary_call()
			else:
				_message("No one to call at this hour.")
		&"power_cut":
			_play("power_down", 0.0)
			get_tree().call_group("camcorder", "glitch", 0.8, 1.2)
			stalker.start_patrol()
			main_switch.enabled = true
		&"meter_room_reached":
			stalker.stop()
			_message("The main switch has tripped.", 3.0)
		&"main_switch":
			_ending()


# --- Beats ----------------------------------------------------------------------------

func _opening() -> void:
	await _wait(2.5)
	for line in OPENING:
		_say(VO, line[0], line[1])
		await _wait(line[1] + 0.4)


func _cut_to_three() -> void:
	await _wait(2.0)
	_say(VO, "The first round was quiet. The first round always is.", 3.5)
	await _wait(3.0)
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	if camcorder:
		camcorder.tape_cut(CUT_TO)
		await camcorder.cut_finished
	_move_stool()
	Game.save_checkpoint(&"start")
	_say(VO, "Around three, I sat down to write the round in the register.", 4.5)


func _wicket(open: bool) -> void:
	var tween := create_tween()
	tween.tween_property(wicket, "rotation_degrees:y", 95.0 if open else 0.0, 1.0 if open else 0.5) \
		.set_trans(Tween.TRANS_SINE)
	var at := wicket.global_position + Vector3(0, 1, 0)
	_play_at("gate_creak" if open else "gate_clang", at, -4.0)


func _intercom_call() -> void:
	intercom_breath.play()
	_say(RAGHU, "Hello? Hello, 4B?", 3.0)
	await _wait(3.4)
	_say("", "[i](slow breathing)[/i]", 3.0)
	await _wait(3.4)
	_say(RAGHU, "Deshmukh-ji? Is that you? Sahab?", 3.0)
	await _wait(3.4)
	intercom_breath.stop()
	_message("The line goes dead.", 3.0)
	cam_4b.active = true
	await _wait(3.0)
	_say(VO, "Somebody had to go up and look. That was my job.", 4.0)


func _secretary_call() -> void:
	_calling = true
	_play("phone_ring", -10.0)
	await _wait(3.2)
	# Branching call (dialogue/tape01/secretary.json): what he says depends on what Raghu
	# promised Deshmukh and heard from Mrs. Iyer. It always ends with the line going dead.
	var view := level.get_node("HUD/DialogueView") as DialogueView
	view.play(SECRETARY_DIALOGUE)
	await view.finished
	Events.fire(&"power_cut")
	Events.fire(&"secretary_called")
	_calling = false
	await _wait(2.0)
	_say(VO, "Then the power went. The whole society, all at once.", 4.0)
	await _wait(4.5)
	_message("The meter room is beside D Wing. Take the torch (F).", 4.0)
	Game.save_checkpoint(&"start")


# --- The first round's people ------------------------------------------------------------

func _process(_delta: float) -> void:
	# Deshmukh calls out once when Raghu comes near B wing.
	if _deshmukh_called or not deshmukh_npc.active or ending_started:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(deshmukh_npc.global_position) < 9.0:
		_deshmukh_called = true
		_say("MR. DESHMUKH", "Watchman-ji.", 2.5)


## After the tape cut, the stool has moved into the cabin's doorway. Nobody moved it.
func _move_stool() -> void:
	stool.position = Vector3(4.45, 0, 23.0)
	stool.rotation_degrees = Vector3(0, 35, 0)


func _deshmukh_goes_in() -> void:
	deshmukh_npc.walk_to(DESHMUKH_STAIRS)
	await deshmukh_npc.arrived
	deshmukh_npc.active = false
	Game.set_flag("t1_deshmukh_gone", true)


func _iyer_comes_down() -> void:
	if Game.get_flag("t1_iyer_home", null) != null:
		return
	iyer.global_position = IYER_HOME
	iyer.active = true
	await _wait(2.0)
	iyer.walk_to(IYER_WAIT)
	await iyer.arrived
	_iyer_waits()


func _iyer_waits() -> void:
	iyer.face(Vector3(5.0, 0, 23.4))  # towards the cabin door
	_say("MRS. IYER", "Watchman-ji? Are you there?", 3.0)


func _iyer_goes_home() -> void:
	await _wait(1.0)
	iyer.walk_to(IYER_HOME)
	await iyer.arrived
	iyer.active = false
	Game.set_flag("t1_iyer_home", true)


func _ending() -> void:
	ending_started = true
	main_switch.enabled = false
	_play("switch_clack", 0.0)
	Events.fire(&"power_restored")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_enabled = false
	await _wait(1.6)
	# The last frame of CAM 4: Raghu at the board, and behind him, a red dot.
	var at := player.global_position if player else Vector3(28.6, 0, -3.0)
	raghu.global_position = Vector3(clampf(at.x, 27.3, 29.3), 0.0, clampf(at.z, -5.3, -2.8))
	raghu.visible = true
	cam_ending.active = true
	stalker.stop()
	_show_cctv_frame()
	get_tree().call_group("camcorder", "glitch", 0.6, 1.0)
	await _wait(4.0)
	get_tree().call_group("camcorder", "show_static")
	await _wait(2.5)
	Game.complete_chapter()


func _show_cctv_frame() -> void:
	var spot := level.get_node("CamSpots/MeterRoom") as Node3D
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = float(spot.get_meta(&"fov", 70.0))
	camera.cull_mask = PropModel.CCTV_CULL_MASK
	viewport.add_child(camera)
	camera.global_transform = spot.global_transform
	camera.current = true
	var layer := CanvasLayer.new()
	layer.layer = 1  # under the camcorder OSD + VHS: the camcorder is filming the monitor
	add_child(layer)
	var picture := TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.modulate = Color(0.85, 1.0, 0.9)
	layer.add_child(picture)
	var label := Label.new()
	label.text = "CAM 4  METER ROOM   %s" % _clock_hms()
	label.position = Vector2(90, 120)
	label.add_theme_font_size_override(&"font_size", 30)
	label.add_theme_color_override(&"font_color", Color(0.7, 1, 0.7))
	layer.add_child(label)
	var hud := level.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false


# --- Helpers ------------------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * time_scale).timeout


func _after(seconds: float, fn: Callable) -> void:
	await _wait(seconds)
	if is_inside_tree() and not ending_started:
		fn.call()


func _say(speaker: String, text: String, seconds: float = 3.5) -> void:
	get_tree().call_group("subtitles", "say", speaker, text, seconds)


func _message(text: String, seconds: float = 2.5) -> void:
	get_tree().call_group("hud", "show_message", text, seconds)


## Remembers when something happened (the stranger's register entries quote it).
func _note_time(id: StringName) -> void:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	if camcorder:
		Game.set_flag("t1_t_" + String(id), camcorder.osd.clock_text())


func _clock_hms() -> String:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	if camcorder == null:
		return ""
	var t: int = camcorder.osd.time_of_day()
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


func _play(sound: String, volume_db: float) -> void:
	_sfx.stream = load(SFX + sound + ".wav")
	_sfx.volume_db = volume_db
	_sfx.play()


func _play_at(sound: String, at: Vector3, volume_db: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = load(SFX + sound + ".wav")
	player.volume_db = volume_db
	player.unit_size = 6.0
	player.bus = &"SFX"
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
