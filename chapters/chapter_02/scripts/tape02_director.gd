extends Node
## Tape 2 (story bible): Salim, 34, the overnight booth at the NH-4 toll plaza, 2 November
## 2001, 1:05 AM. Routine first (radio check-in, three vehicles: take the toll, lift the
## barrier, log the plate), then a white Omni van, plate MH 04 AX 0312, every twenty minutes
## (tape cuts): an old driver, a young one, one in Salim's own uniform; one more passenger in
## the back each time, Raghu among them on the fourth. At 3:12 it stops at the window and
## doesn't move: the ending (data/sequences/tape02/ending.json).
##
## The night is a chain decided from EventBus counts and flags in _advance(), so a checkpoint
## reload picks up wherever it was. Node names are the ones tools/gen_tape02.py writes.

const VO := "SALIM (V.O.)"
const SALIM := "SALIM"
const OPENING := [
	["Salim. Thirty-four. Night booth at the NH-4 toll plaza. November, 2001.", 4.5],
	["Nobody drives that road after one. That's why they gave the night to me.", 4.5],
	["Take the money, tear the receipt, write the plate, lift the arm. That was the whole job.", 5.0],
]
const SFX := "res://assets/audio/sfx/"
const SEQUENCES: Array[String] = ["res://data/sequences/tape02/ending.json"]
const VAN_PLATE := "MH 04 AX 0312"
## The three ordinary vehicles of the first hour: node, plate, how Salim logs it.
const NORMALS := [
	["Car1", "MH 12 KT 4471", "Maruti 800, white. Rs 15."],
	["Tempo", "MH 43 E 7710", "Tempo, onions. Rs 40."],
	["Car2", "GJ 05 CR 2208", "Ambassador, red. Rs 15."],
]
## The van's four passes: tape cut, driver, passengers in the back, Raghu, objective gate.
const PASSES := [
	{"cut": "01:52:10", "driver": "DriverOld", "passengers": 1, "raghu": false, "after": &"log_written"},
	{"cut": "02:12:20", "driver": "DriverYoung", "passengers": 2, "raghu": false, "after": &"radio_van"},
	{"cut": "02:32:30", "driver": "DriverUniform", "passengers": 3, "raghu": false, "after": &"lane_checked"},
	{"cut": "02:52:40", "driver": "DriverUniform", "passengers": 3, "raghu": true, "after": &"radio_dead"},
]
const LAST_CUT := "03:11:40"
const VO_BEATS := {
	&"van_served_1": [2.0, "Bombay plate. MH 04 AX 0312. An old man driving. Exact change. He never looked at me.", 5.0],
	&"van_served_2": [2.0, "Same van. Same plate. The driver was young this time. Younger than me.", 4.5],
	&"van_served_3": [2.0, "He was wearing my uniform. My name badge. I checked my own shirt. It was still on me.", 5.0],
	&"van_served_4": [2.0, "Four of them in the back now. The one by the window wore a watchman's khaki. He never blinked.", 5.0],
	&"log_read_late": [1.0, "I never wrote that line. I know my own hand.", 3.5],
}
## Story tension by how far the night has gone (EventBus counts, so checkpoints keep it).
const TENSION_BEATS := [
	[&"log_written", 0.1], [&"van_served_1", 0.25], [&"van_served_2", 0.35], [&"lane_checked", 0.45],
	[&"van_served_3", 0.55], [&"radio_dead", 0.6], [&"van_served_4", 0.65], [&"log_read_late", 0.7],
]

## Multiplies every scripted wait (tests make it small).
var time_scale: float = 1.0
var ending_started: bool = false
var sequences: SequencePlayer
## The vehicle at (or coming to) the window.
var current: TollVehicle
var _busy: bool = false
var _sfx: AudioStreamPlayer

@onready var level: Node = get_parent()
@onready var van: TollVehicle = level.get_node("Vehicles/Van")
@onready var barrier: Node3D = level.get_node("Barrier/Arm")
@onready var cctv: CCTVMonitor = level.get_node("CCTV")
@onready var cam_road: Cameraman = level.get_node("CamRoad")
@onready var cam_lane: Cameraman = level.get_node("CamLane")
@onready var spot_cctv: Spottable = level.get_node("SpotCCTV")
@onready var cam_backseat: Cameraman = level.get_node("Vehicles/Van/CamBackseat")


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	add_child(_sfx)
	sequences = SequencePlayer.new()
	sequences.name = "Sequences"
	sequences.sequences = SEQUENCES
	sequences.root = NodePath("../..")
	add_child(sequences)
	for v in _vehicles():
		v.gone.connect(_on_gone.bind(v))
		v.arrived.connect(_on_arrived.bind(v))
	EventBus.fired.connect(_on_event)
	_update_tension.call_deferred()
	_advance.call_deferred()
	if GameManager.get_flag("t2_opening") == null and not EventBus.has_fired(&"radio_checkin"):
		GameManager.set_flag("t2_opening", true)
		_opening()


func _process(_delta: float) -> void:
	sequences.time_scale = time_scale
	for v in _vehicles():
		v.time_scale = time_scale


## Decides what happens next from what has already happened (also after a reload).
func _advance() -> void:
	if ending_started or _busy or current != null:
		return
	if not EventBus.has_fired(&"radio_checkin"):
		return
	var served := EventBus.count(&"vehicle_served")
	if served < NORMALS.size():
		_bring(level.get_node("Vehicles/" + String(NORMALS[served][0])) as TollVehicle, 4.0 if served == 0 else 6.0)
		return
	for i in PASSES.size():
		if EventBus.has_fired(StringName("van_served_%d" % (i + 1))):
			continue
		if not EventBus.has_fired(PASSES[i].after):
			return
		_van_pass(i)
		return
	if EventBus.has_fired(&"log_read_late"):
		_last_van()


func _bring(v: TollVehicle, delay: float) -> void:
	current = v
	_busy = true
	await _wait(delay)
	_busy = false
	if current == v and v.state == TollVehicle.State.PARKED:
		v.drive_up()


func _van_pass(i: int) -> void:
	var pass_data: Dictionary = PASSES[i]
	current = van
	_busy = true
	var flag := "t2_cut_%d" % (i + 1)
	if GameManager.get_flag(flag) == null:
		await _wait(3.0)
		GameManager.set_flag(flag, true)
		await _tape_cut(String(pass_data.cut))
		GameManager.save_checkpoint(&"booth")
	_dress_van(String(pass_data.driver), int(pass_data.passengers), bool(pass_data.raghu))
	cam_road.active = i == 2
	await _wait(4.0)
	_busy = false
	van.drive_up()


func _last_van() -> void:
	current = van
	_busy = true
	if GameManager.get_flag("t2_cut_5") == null:
		await _wait(3.0)
		GameManager.set_flag("t2_cut_5", true)
		await _tape_cut(LAST_CUT)
		GameManager.save_checkpoint(&"booth")
	_dress_van("DriverUniform", 4, true)
	await _wait(4.0)
	_busy = false
	van.drive_up()


func _dress_van(driver: String, passengers: int, raghu: bool) -> void:
	for d in ["DriverOld", "DriverYoung", "DriverUniform"]:
		(van.get_node(d) as Node3D).visible = d == driver
	for i in 4:
		var p := van.get_node_or_null("Passengers/P%d" % (i + 1)) as Node3D
		if p:
			p.visible = i < passengers
	(van.get_node("Passengers/Raghu") as Node3D).visible = raghu


func _on_arrived(v: TollVehicle) -> void:
	if v == van:
		if GameManager.get_flag("t2_cut_5") != null and EventBus.has_fired(&"log_read_late"):
			_message("The van has stopped at the window. The engine is still running.", 4.0)
		elif not EventBus.has_fired(&"van_served_1"):
			_think("A van. At this hour.", 2.5)
	else:
		_message("A vehicle at the window.", 2.0)


func _on_gone(v: TollVehicle) -> void:
	_lower_barrier()
	if current != v:
		return
	current = null
	if v == van:
		for i in PASSES.size():
			var id := StringName("van_served_%d" % (i + 1))
			if not EventBus.has_fired(id):
				EventBus.fire(id)
				break
		cam_road.active = false
	else:
		EventBus.fire(&"vehicle_served")
	_advance()


func _on_event(id: StringName) -> void:
	if EventBus.replaying or ending_started:
		return
	_update_tension()
	if VO_BEATS.has(id) and GameManager.get_flag("t2_vo_" + String(id)) == null:
		GameManager.set_flag("t2_vo_" + String(id), true)
		var beat: Array = VO_BEATS[id]
		_after(beat[0], _say.bind(VO, beat[1], beat[2], "t2/vo_" + String(id)))
	match id:
		&"toll_window":
			_take_toll()
		&"barrier_button":
			_lift_barrier()
		&"radio_used":
			_radio()
		&"cctv_checked":
			if ObjectiveManager.is_active(&"check_cctv"):
				cctv.show_camera(0, 4.0)
				cam_lane.active = true
				spot_cctv.active = true
				_message("CAM 1. LANE 3 ENTRY. Empty road. ...Someone standing at the far end.", 4.0)
				_after(3.0, func() -> void:
					EventBus.fire(&"lane_checked")
					_after(6.0, func() -> void:
						cam_lane.active = false
						spot_cctv.active = false))
		&"radio_checkin", &"log_written", &"radio_van", &"lane_checked", &"radio_dead", &"log_read_late":
			_advance()


func _take_toll() -> void:
	if current == null or not current.is_waiting():
		_message("No one at the window.", 2.0)
		return
	if current.paid:
		_message("Paid. Lift the barrier.", 2.0)
		return
	if current == van and GameManager.get_flag("t2_cut_5") != null and EventBus.has_fired(&"log_read_late"):
		EventBus.fire(&"last_toll")  # the ending: data/sequences/tape02/ending.json
		return
	current.paid = true
	_play("coins", -4.0)
	_after(0.5, _play.bind("receipt_print", -6.0))
	var clock := _clock()
	if current == van:
		PlateLog.write(VAN_PLATE, "Omni, white. Rs 15. Exact change.", clock)
		_message("Rs 15, exact change. Receipt. Plate: %s." % VAN_PLATE, 3.5)
	else:
		for n: Array in NORMALS:
			if level.get_node("Vehicles/" + String(n[0])) == current:
				PlateLog.write(String(n[1]), String(n[2]), clock)
				_message("Toll taken. Receipt. Plate: %s." % n[1], 3.0)
	EventBus.fire(&"toll_taken")


func _lift_barrier() -> void:
	if current == null or not current.is_waiting():
		_message("Nothing waiting at the barrier.", 2.0)
		return
	if not current.paid:
		_message("Take the toll first.", 2.0)
		return
	_play("barrier_motor", -6.0)
	var tw := create_tween()
	tw.tween_property(barrier, "rotation_degrees:z", -82.0, 1.2 * time_scale)  # arm points -X.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(current.leave)
	EventBus.fire(&"barrier_raised")


func _lower_barrier() -> void:
	if absf(barrier.rotation_degrees.z) < 1.0:
		return
	_play("barrier_motor", -8.0)
	create_tween().tween_property(barrier, "rotation_degrees:z", 0.0, 1.2 * time_scale).set_trans(Tween.TRANS_SINE)


func _radio() -> void:
	_play("radio_squelch", -6.0)
	var file := ""
	if ObjectiveManager.is_active(&"radio_checkin"):
		file = "radio_checkin"
	elif ObjectiveManager.is_active(&"radio_van"):
		file = "radio_van"
	elif ObjectiveManager.is_active(&"radio_again"):
		file = "radio_dead"
	if file == "":
		_message("Control is quiet. Just the carrier hiss.", 2.5)
		return
	get_tree().call_group("hud", "start_dialogue", "res://data/dialogue/tape02/%s.json" % file, "")


# --- the ending (called by data/sequences/tape02/ending.json) ----------------------------

func begin_ending() -> void:
	ending_started = true
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_enabled = false
	_play("coins", -4.0)


func show_receipt() -> void:
	var text := "[b]NH-4 TOLL PLAZA — BOOTH 3[/b]\nRECEIPT No. 0312\n02/11/2001   03:12\n\nVEHICLE:  %s  (OMNI)\nAMOUNT:  Rs 15.00   PAID\n\n[b]ISSUED TO:  SALIM KHAN[/b]\n\nHAPPY JOURNEY" % VAN_PLATE
	get_tree().call_group("hud", "show_note", text, false)


func hide_receipt() -> void:
	var note := level.get_node_or_null("HUD/NoteView")
	if note and note.has_method(&"close"):
		note.call(&"close")


func lights_die() -> void:
	EventBus.fire(&"power_cut")
	_play("power_down", 0.0)
	get_tree().call_group("camcorder", "glitch", 0.6, 1.0)


func red_dot() -> void:
	cam_backseat.active = true
	# with the plaza dark, the dot has to read: a faint red spill on the seat and the glass
	var glow := OmniLight3D.new()
	glow.name = "DotGlow"
	glow.light_color = Color(1.0, 0.06, 0.03)
	glow.light_energy = 1.8
	glow.omni_range = 2.6
	glow.shadow_enabled = false
	cam_backseat.add_child(glow)
	glow.position = Vector3(0, 1.35, -0.25)


func finish() -> void:
	GameManager.complete_chapter()


# --- helpers ---------------------------------------------------------------------------

func _opening() -> void:
	await _wait(2.5)
	for i in OPENING.size():
		var line: Array = OPENING[i]
		_say(VO, line[0], line[1], "t2/opening_%d" % (i + 1))
		await _wait(line[1] + 0.4)


func _tape_cut(to: String) -> void:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	if camcorder:
		camcorder.tape_cut(to)
		await camcorder.cut_finished


func _update_tension() -> void:
	var level_value := 0.0
	for beat: Array in TENSION_BEATS:
		if EventBus.has_fired(beat[0]):
			level_value = beat[1]
	AudioManager.set_tension(level_value, &"story")


func _vehicles() -> Array[TollVehicle]:
	var out: Array[TollVehicle] = []
	for c in level.get_node("Vehicles").get_children():
		if c is TollVehicle:
			out.append(c as TollVehicle)
	return out


func _clock() -> String:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	return camcorder.osd.clock_text().left(5) if camcorder else "--:--"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * time_scale, false).timeout


func _after(seconds: float, f: Callable) -> void:
	get_tree().create_timer(seconds * time_scale, false).timeout.connect(f)


func _say(speaker: String, text: String, seconds: float = 3.5, voice_id: String = "") -> void:
	get_tree().call_group("subtitles", "say", speaker, text, seconds, voice_id)


func _think(text: String, seconds: float = 3.0) -> void:
	get_tree().call_group("subtitles", "think", text, seconds)


func _message(text: String, seconds: float = 2.5) -> void:
	get_tree().call_group("hud", "show_message", text, seconds)


func _play(name: String, volume_db: float) -> void:
	var stream := load(SFX + name + ".wav") as AudioStream
	if stream:
		AudioManager.play_sfx(stream, volume_db)
