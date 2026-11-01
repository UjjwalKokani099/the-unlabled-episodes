class_name Subtitles
extends CanvasLayer
## Bottom-centre subtitles. Anything can speak:
##     get_tree().call_group("subtitles", "say", "Vendor", "Le jao.", 3.0)
## Respects Settings.subtitles (off = nothing shown) and Settings.subtitle_size.

const SIZES := [22, 28, 36]

@onready var _label: RichTextLabel = $Label
var _tween: Tween


func _ready() -> void:
	add_to_group("subtitles")
	_label.modulate.a = 0.0


func say(speaker: String, text: String, seconds: float = 3.0) -> void:
	if not Settings.subtitles:
		return
	_label.add_theme_font_size_override(&"normal_font_size", SIZES[Settings.subtitle_size])
	_label.text = "[center][color=#ffd27a]%s:[/color] %s[/center]" % [speaker, text] if speaker != "" else "[center]%s[/center]" % text
	if _tween:
		_tween.kill()
	_label.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(seconds)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.4)


func current_text() -> String:
	return _label.get_parsed_text() if _label.modulate.a > 0.0 else ""
