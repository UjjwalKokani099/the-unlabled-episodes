extends Node3D
## Shanti Vihar gate register on the watchman's table (story bible: "paper records").
## Reading it writes whatever Raghu's current duty asks for, in his hand:
##   sign in (register_signed) -> 3 AM round (register_3am) -> Deshmukh out (deshmukh_logged).
## After 4B, the page already holds entries in someone else's hand, logging Raghu's own
## movements to the minute (register_read_late). Times come from the camcorder clock and
## are kept as Game flags ("t1_t_<event>", set by the director), so checkpoints keep them.

const RAGHU_FONT := "res://ui/fonts/hand_raghu.tres"
const STRANGER_FONT := "res://ui/fonts/hand_stranger.tres"

@onready var _area: Interactable = $Interactable


func _ready() -> void:
	_area.interacted.connect(_read)


func _read(_by: Node3D = null) -> void:
	var to_fire: Array[StringName] = []
	if not Events.has_fired(&"register_signed"):
		to_fire.append(&"register_signed")
	if Objectives.is_active(&"sign_3am"):
		Game.set_flag("t1_t_register_3am", _clock())
		to_fire.append(&"register_3am")
	if Objectives.is_active(&"log_deshmukh"):
		to_fire.append(&"deshmukh_logged")
	if Objectives.is_active(&"read_register") and Game.get_flag("t1_t_reading") == null:
		Game.set_flag("t1_t_reading", _clock())
		to_fire.append(&"register_read_late")
	get_tree().call_group("hud", "show_note", page(to_fire), false)
	for id in to_fire:
		Events.fire(id)


## The page as it reads now (plus the lines about to be written by `writing`).
func page(writing: Array[StringName] = []) -> String:
	var has := func(id: StringName) -> bool: return Events.has_fired(id) or id in writing
	var text := "[b]SHANTI VIHAR CO-OP. HSG. SOCIETY — GATE REGISTER[/b]\n\n"
	text += "13/03/98   06:00 AM   Kishan     Night duty over. All OK.\n"
	text += "13/03/98   10:30 PM   Kishan     [i](no entry — did not come)[/i]\n"
	text += "14/03/98   09:15 PM   Courier for 2C. Left parcel.\n"
	text += _hand(RAGHU_FONT, "14/03/98   10:40 PM   Raghu      Night duty start.   Sign: Raghu")
	if has.call(&"register_3am"):
		text += _hand(RAGHU_FONT, "15/03/98   %s   Raghu      Round done. Terraces locked. All OK." % _flag("t1_t_register_3am"))
	if has.call(&"deshmukh_logged"):
		text += _hand(RAGHU_FONT, "15/03/98   03:12 AM   Mr. Deshmukh (4B) went out. Did not say where.")
	if has.call(&"register_read_late"):
		for line in [["t1_t_balcony_checked", "Raghu stood in the courtyard. Looked up at 4B."],
				["t1_t_intercom_answered", "Raghu picked up the intercom. Listened."],
				["t1_t_4b_checked", "Raghu went into 4B."],
				["t1_t_cabin_return2", "Raghu came back to the cabin."],
				["t1_t_reading", "Raghu is reading this."]]:
			text += _hand(STRANGER_FONT, "15/03/98   %s   %s" % [_flag(line[0]), line[1]])
	return text


func _hand(font: String, line: String) -> String:
	return "[font=%s]%s[/font]\n" % [font, line]


func _flag(key: String) -> String:
	return str(Game.get_flag(key, "03:--"))


func _clock() -> String:
	var camcorder := get_tree().get_first_node_in_group("camcorder")
	return camcorder.osd.clock_text() if camcorder else "03:--"
