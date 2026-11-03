class_name VanishWhenUnseen
extends Node3D
## Visible until the player has looked at it and then looked away: then it is gone
## (story: the white van in the lane). Needs a VisibleOnScreenNotifier3D child "Notifier".

signal vanished

var _seen: bool = false


func _ready() -> void:
	var notifier := $Notifier as VisibleOnScreenNotifier3D
	notifier.screen_entered.connect(func() -> void: _seen = true)
	notifier.screen_exited.connect(func() -> void:
		if _seen and visible:
			visible = false
			process_mode = Node.PROCESS_MODE_DISABLED
			vanished.emit())
