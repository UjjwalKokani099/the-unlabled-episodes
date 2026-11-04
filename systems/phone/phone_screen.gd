class_name PhoneScreen
extends Control
## What Nikhil's phone shows: a real-time UI rendered in a SubViewport onto the 3D phone
## (PlayerPhone). Built in code from data/phone/<place>.json (format in that file).
##
## Pages: home (clock, date, notifications, apps), messages, a thread (bubbles + one-tap
## reply), calls (log), incoming call (Answer / Decline), in call, torch. Navigation is a
## highlighted row: move(+-1), select(), back(); tap_at(pos) for touch. Replies and answered
## calls fire their EventBus ids; the phone owner listens to the signals below.

signal torch_requested
signal call_answered(contact: String, dialogue: String)
signal call_declined(contact: String)

const SIZE := Vector2i(360, 760)
const FONT: Font = preload("res://assets/fonts/ui.tres")
const FONT_BOLD: Font = preload("res://assets/fonts/ui_bold.tres")
const BG := Color(0.055, 0.06, 0.075)
const ROW := Color(1, 1, 1, 0.06)
const ROW_SELECTED := Color(0.35, 0.55, 0.95, 0.35)
const ACCENT := Color(0.45, 0.65, 1.0)
const DIM := Color(1, 1, 1, 0.55)

var contacts: Dictionary = {}
var threads: Array = []          # [{id, contact, messages, reply, replied}]
var calls: Array = []
var page: String = "home"
var page_arg: String = ""
var selected: int = 0
var battery: float = 0.34
var charging: bool = false
var torch_on: bool = false
var in_call_seconds: float = 0.0

var _rows: Array[Control] = []   # selectable rows of the current page
var _row_actions: Array[Callable] = []
var _content: VBoxContainer
var _time: Label
var _status: Label
var _unread: Dictionary = {}     # thread id -> count
var _incoming: Dictionary = {}   # {contact, dialogue} while ringing
var _stack: Array[String] = []


func _ready() -> void:
	size = SIZE
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(SIZE)
	add_child(bg)
	var bar := HBoxContainer.new()
	bar.position = Vector2(22, 10)
	bar.size = Vector2(SIZE.x - 44, 28)
	add_child(bar)
	_time = _label("", 17, Color.WHITE, FONT_BOLD)
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_time)
	_status = _label("", 16, Color.WHITE)
	bar.add_child(_status)
	_content = VBoxContainer.new()
	_content.position = Vector2(16, 48)
	_content.size = Vector2(SIZE.x - 32, SIZE.y - 64)
	_content.add_theme_constant_override(&"separation", 10)
	add_child(_content)
	show_page("home")


## Loads contacts, threads and the call log for hub stage `stage`.
func load_data(path: String, stage: int) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		push_error("PhoneScreen: bad data %s" % path)
		return {}
	contacts = data.get("contacts", {})
	threads.clear()
	for t: Dictionary in data.get("threads", []):
		if _in_stage(t, stage):
			var copy := t.duplicate(true)
			copy["replied"] = copy.has("reply") and EventBus.has_fired(StringName(copy.reply.get("event", "")))
			threads.append(copy)
			if not copy.replied and copy.has("reply"):
				_unread[copy.id] = (copy.messages as Array).size()
	calls = (data.get("calls", []) as Array).filter(func(c: Dictionary) -> bool: return _in_stage(c, stage))
	show_page(page)
	return data


static func _in_stage(entry: Dictionary, stage: int) -> bool:
	return stage >= int(entry.get("min_stage", 0)) and stage <= int(entry.get("max_stage", 99))


func unread_count() -> int:
	var n := 0
	for k: String in _unread:
		n += int(_unread[k])
	return n


## A text arrives (the owner buzzes).
func receive_text(thread_id: String, message: Dictionary) -> void:
	var thread := _thread(thread_id)
	if thread.is_empty():
		return
	var m := message.duplicate()
	if m.get("time", "") == "now":
		m.time = _clock()
	(thread.messages as Array).append(m)
	_unread[thread_id] = int(_unread.get(thread_id, 0)) + 1
	show_page(page, page_arg)


## Someone calls: the phone shows the incoming call until answered or declined.
func ring(contact: String, dialogue: String) -> void:
	_incoming = {"contact": contact, "dialogue": dialogue}
	show_page("incoming")


func is_ringing() -> bool:
	return not _incoming.is_empty()


func end_call() -> void:
	_incoming = {}
	if page == "in_call":
		show_page("home")


# --- navigation ----------------------------------------------------------------------

func move(step: int) -> void:
	if _rows.is_empty():
		return
	selected = wrapi(selected + step, 0, _rows.size())
	_highlight()


func select() -> void:
	if selected >= 0 and selected < _row_actions.size():
		AudioManager.play_ui(&"click")
		_row_actions[selected].call()


func back() -> bool:
	if page in ["incoming", "in_call"]:
		return false
	if _stack.is_empty():
		return false
	var prev: String = _stack.pop_back()
	var parts := prev.split(":", true, 1)
	_show(parts[0], parts[1] if parts.size() > 1 else "")
	AudioManager.play_ui(&"back")
	return true


## Touch / mouse: select the row under `pos` (screen pixels).
func tap_at(pos: Vector2) -> void:
	for i in _rows.size():
		if _rows[i].get_global_rect().has_point(pos):
			selected = i
			_highlight()
			select()
			return


## Rows on this page as plain text (tests).
func row_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for r in _rows:
		var texts: Array[String] = []
		for l in r.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
		out.append(" | ".join(texts))
	return out


func show_page(name: String, arg: String = "") -> void:
	if name != page or arg != page_arg:
		if page not in ["incoming", "in_call"]:
			_stack.append(page + (":" + page_arg if page_arg != "" else ""))
	_show(name, arg)


func _process(delta: float) -> void:
	_time.text = _clock()
	var pct := roundi(battery * 100.0)
	_status.text = "▂▄▆  4G   %s%d%%" % ["⚡" if charging else "", pct]
	if page == "in_call":
		in_call_seconds += delta
		var l := _content.find_child("CallTimer", true, false) as Label
		if l:
			l.text = "%02d:%02d" % [int(in_call_seconds) / 60, int(in_call_seconds) % 60]


# --- pages ---------------------------------------------------------------------------

func _show(name: String, arg: String) -> void:
	page = name
	page_arg = arg
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_rows.clear()
	_row_actions.clear()
	selected = 0
	match name:
		"home":
			_page_home()
		"messages":
			_page_messages()
		"thread":
			_page_thread(arg)
		"calls":
			_page_calls()
		"incoming":
			_page_incoming()
		"in_call":
			_page_in_call()
	_highlight()


func _page_home() -> void:
	_content.add_child(_spacer(30))
	var clock := _label(_clock(), 72, Color.WHITE, FONT)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(clock)
	var d := Time.get_datetime_dict_from_system()
	var days := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September",
		"October", "November", "December"]
	var date := _label("%s, %d %s" % [days[d.weekday], d.day, months[d.month - 1]], 19, DIM)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(date)
	_content.add_child(_spacer(24))
	for t: Dictionary in threads:
		if int(_unread.get(t.id, 0)) > 0:
			var last: Dictionary = (t.messages as Array).back()
			_add_row(contacts.get(t.contact, t.contact) + "   " + String(last.get("time", "")), _short(last.text),
				_open_thread.bind(String(t.id)), true)
	_content.add_child(_spacer(10))
	var unread := unread_count()
	_add_row("Messages" + ("  (%d)" % unread if unread > 0 else ""), "", show_page.bind("messages", ""))
	var missed := calls.filter(func(c: Dictionary) -> bool: return c.kind == "missed").size()
	_add_row("Phone" + ("  (%d missed)" % missed if missed > 0 else ""), "", show_page.bind("calls", ""))
	_add_row("Torch: " + ("On" if torch_on else "Off"), "", func() -> void: torch_requested.emit())


func _page_messages() -> void:
	_content.add_child(_title("Messages"))
	for t: Dictionary in threads:
		var last: Dictionary = (t.messages as Array).back()
		var name := String(contacts.get(t.contact, t.contact))
		var dot := "●  " if int(_unread.get(t.id, 0)) > 0 else ""
		_add_row(dot + name, _short(("You: " if last.get("from") == "me" else "") + String(last.text)),
			_open_thread.bind(String(t.id)))


func _page_thread(id: String) -> void:
	var t := _thread(id)
	if t.is_empty():
		return
	_unread.erase(id)
	_content.add_child(_title(String(contacts.get(t.contact, t.contact))))
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 8)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(list)
	var shown: Array = (t.messages as Array).slice(-6)
	for m: Dictionary in shown:
		list.add_child(_bubble(m))
	if t.has("reply") and not t.replied:
		var r: Dictionary = t.reply
		_add_row("Reply", _short(String(r.text), 60), _send_reply.bind(id))
	EventBus.fire(StringName("read_thread_" + id))


func _page_calls() -> void:
	_content.add_child(_title("Recent"))
	for c: Dictionary in calls.slice(-6):
		var kind: String = c.kind
		var sign: String = {"missed": "↙ missed", "incoming": "↙", "outgoing": "↗"}.get(kind, "")
		var row := _row_box(String(contacts.get(c.contact, c.contact)), "%s   %s" % [sign, c.when], false)
		if kind == "missed":
			(row.find_child("Title", true, false) as Label).add_theme_color_override(&"font_color", Color(1, 0.45, 0.4))
		_content.add_child(row)


func _page_incoming() -> void:
	_content.add_child(_spacer(90))
	var who := _label(String(contacts.get(_incoming.contact, _incoming.contact)), 40, Color.WHITE, FONT_BOLD)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(who)
	var sub := _label("Incoming call…", 20, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(sub)
	_content.add_child(_spacer(200))
	_add_row("Answer", "", _answer)
	_add_row("Decline", "", _decline)


func _page_in_call() -> void:
	_content.add_child(_spacer(90))
	var who := _label(String(contacts.get(_incoming.get("contact", ""), "")), 40, Color.WHITE, FONT_BOLD)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(who)
	var timer := _label("00:00", 22, DIM)
	timer.name = "CallTimer"
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(timer)


# --- actions --------------------------------------------------------------------------

func _open_thread(id: String) -> void:
	show_page("thread", id)


func _send_reply(id: String) -> void:
	var t := _thread(id)
	if t.is_empty() or t.replied:
		return
	t.replied = true
	var r: Dictionary = t.reply
	(t.messages as Array).append({"from": "me", "time": _clock(), "text": r.text, "tr": r.get("tr", "")})
	if String(r.get("event", "")) != "":
		EventBus.fire(StringName(r.event))
	_show("thread", id)


func _answer() -> void:
	in_call_seconds = 0.0
	var c: Dictionary = _incoming
	calls.append({"contact": c.contact, "when": "Today, " + _clock(), "kind": "incoming"})
	_show("in_call", "")
	call_answered.emit(String(c.contact), String(c.dialogue))


func _decline() -> void:
	var c: Dictionary = _incoming
	_incoming = {}
	calls.append({"contact": c.contact, "when": "Today, " + _clock(), "kind": "missed"})
	call_declined.emit(String(c.contact))
	_show("home", "")


# --- building blocks ---------------------------------------------------------------------

func _thread(id: String) -> Dictionary:
	for t: Dictionary in threads:
		if t.id == id:
			return t
	return {}


func _clock() -> String:
	var t := Time.get_time_dict_from_system()
	return "%d:%02d" % [t.hour, t.minute]


func _short(text: String, n: int = 38) -> String:
	return text if text.length() <= n else text.substr(0, n - 1) + "…"


func _label(text: String, size_px: int, color: Color, font: Font = FONT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size_px)
	l.add_theme_color_override(&"font_color", color)
	return l


func _title(text: String) -> Label:
	return _label(text, 28, Color.WHITE, FONT_BOLD)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _row_box(title: String, sub: String, notification: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ROW if not notification else Color(1, 1, 1, 0.1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	var t := _label(title, 21, Color.WHITE, FONT_BOLD)
	t.name = "Title"
	box.add_child(t)
	if sub != "":
		var s := _label(sub, 17, DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(s)
	return panel


func _add_row(title: String, sub: String, action: Callable, notification: bool = false) -> void:
	var row := _row_box(title, sub, notification)
	_content.add_child(row)
	_rows.append(row)
	_row_actions.append(action)


func _bubble(m: Dictionary) -> Control:
	var mine: bool = m.get("from") == "me"
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.42, 0.85) if mine else Color(1, 1, 1, 0.11)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override(&"panel", style)
	panel.custom_minimum_size.x = 0
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	var text := _label(String(m.text), 18, Color.WHITE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 230
	box.add_child(text)
	if String(m.get("tr", "")) != "":
		var tr := _label("(" + String(m.tr) + ")", 14, Color(1, 1, 1, 0.5))
		tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tr.custom_minimum_size.x = 230
		box.add_child(tr)
	var time := _label(String(m.get("time", "")), 12, Color(1, 1, 1, 0.45))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(time)
	wrap.add_child(panel)
	return wrap


func _highlight() -> void:
	for i in _rows.size():
		var style := (_rows[i] as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxFlat
		var fresh := style.duplicate() as StyleBoxFlat
		fresh.bg_color = ROW_SELECTED if i == selected else ROW
		fresh.border_width_left = 4 if i == selected else 0
		fresh.border_color = ACCENT
		(_rows[i] as PanelContainer).add_theme_stylebox_override(&"panel", fresh)
