extends Node3D
## Shanti Vihar gate register on the watchman's table. Reading it the first time signs Raghu
## in (Events `register_signed`). Later beats will add entries he didn't write.

@onready var _area: Interactable = $Interactable


func _ready() -> void:
	_area.interacted.connect(_read)


func _read(_by: Node3D = null) -> void:
	var signed := Events.has_fired(&"register_signed")
	var text := "[b]SHANTI VIHAR CO-OP. HSG. SOCIETY — GATE REGISTER[/b]\n\n"
	text += "13/03/98   06:00 AM   Kishan     Night duty over. All OK.\n"
	text += "13/03/98   10:30 PM   Kishan     [i](no entry — did not come)[/i]\n"
	text += "14/03/98   09:15 PM   Courier for 2C. Left parcel.\n"
	text += "14/03/98   10:40 PM   [b]Raghu[/b]      Night duty start.  Sign: [i]Raghu[/i]\n"
	get_tree().call_group("hud", "show_note", text, false)
	if not signed:
		Events.fire(&"register_signed")
