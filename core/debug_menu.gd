extends CanvasLayer
## Debug menu (studio spec 13), autoload `DebugMenu`, debug builds only (a release export
## frees it at start). F1 opens a panel on the right: jump to any chapter or the room, jump to
## the level's checkpoints (or reload the saved one), noclip, FPS counter, show trigger zones,
## give items, switch the AI off. The game keeps running behind it; the mouse is free while
## it's open.
##
## Noclip: fly where you look (WASD, run = faster, crouch = down), through walls.
## Show triggers: every Area3D in the level drawn as a tinted box with its name: story
## triggers red, checkpoints green, hiding spots blue, acoustic zones faint grey.

signal toggled(open: bool)

const WIDTH := 430.0

var is_open: bool = false
var noclip: bool = false
var triggers_shown: bool = false
var ai_enabled: bool = true

var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label
var _trigger_root: Node3D
var _had_mouse: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	get_tree().scene_changed.connect(_on_scene_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_open(not is_open)


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	_panel.visible = open
	if open:
		_had_mouse = InputManager.mouse_captured()
		InputManager.capture_mouse(false)
		rebuild()
	elif _had_mouse and not get_tree().paused:
		InputManager.capture_mouse(true)
	toggled.emit(open)


# --- actions (also called by tests) -----------------------------------------------------

func jump_to_chapter(id: StringName) -> bool:
	set_open(false)
	return GameManager.start_chapter(id)


func jump_to_hub() -> void:
	set_open(false)
	GameManager.enter_hub()


## Checkpoint areas of the current level.
func checkpoints() -> Array[Checkpoint]:
	var out: Array[Checkpoint] = []
	var scene := get_tree().current_scene
	if scene:
		for n in scene.find_children("*", "Area3D", true, false):
			if n is Checkpoint:
				out.append(n as Checkpoint)
	return out


## Puts the player at a checkpoint (standing on its floor, facing its -Z).
func jump_to_checkpoint(cp: Checkpoint) -> void:
	var player := _player()
	if player == null or cp == null:
		return
	player.velocity = Vector3.ZERO
	player.global_position = cp.global_position + Vector3(0, 0.05, 0)
	player.rotation.y = cp.global_rotation.y


func set_noclip(on: bool) -> void:
	noclip = on
	var player := _player()
	if player:
		player.noclip = on


func set_show_fps(on: bool) -> void:
	SettingsManager.show_fps = on


func set_show_triggers(on: bool) -> void:
	triggers_shown = on
	if _trigger_root:
		_trigger_root.queue_free()
		_trigger_root = null
	if on:
		_draw_triggers()


## Item ids the level's pickups hand out (what "give" offers).
func level_items() -> Array[Pickup]:
	var out: Array[Pickup] = []
	var scene := get_tree().current_scene
	if scene:
		for n in scene.find_children("*", "", true, false):
			if n is Pickup:
				out.append(n as Pickup)
	return out


## As if picked up: inventory + the item's event (objectives count it).
func give_item(id: StringName, display_name: String) -> void:
	GameManager.add_item(id, display_name)
	EventBus.fire(id)
	get_tree().call_group("hud", "show_message", "[debug] Given: %s" % display_name)


## Every NPC, scripted walker, the Stalker and the Cameraman stop (process off) or resume.
func set_ai(on: bool) -> void:
	ai_enabled = on
	var scene := get_tree().current_scene
	if scene == null:
		return
	for n in scene.find_children("*", "", true, false):
		if n is NPC or n is NPCWalker or n is Stalker or n is Cameraman:
			n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Number of trigger boxes drawn (tests).
func trigger_count() -> int:
	return _trigger_root.get_child_count() if _trigger_root else 0


# --- UI ----------------------------------------------------------------------------------

func rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_heading("CHAPTERS")
	if GameManager.chapter_list:
		for ch in GameManager.chapter_list.chapters + GameManager.chapter_list.debug_chapters:
			var b := _button("%s  %s" % [ch.title, ch.subtitle], jump_to_chapter.bind(ch.id))
			b.disabled = not ch.is_built()
	_button("NIKHIL'S ROOM", jump_to_hub)
	var cps := checkpoints()
	if not cps.is_empty() or GameManager.has_checkpoint():
		_heading("CHECKPOINTS")
		if GameManager.has_checkpoint():
			_button("LOAD SAVED  (%s)" % GameManager.saved_checkpoint_id(), func() -> void:
				set_open(false)
				GameManager.load_checkpoint())
		for cp in cps:
			_button("GO TO  %s" % cp.checkpoint_id, jump_to_checkpoint.bind(cp))
	_heading("CHEATS")
	_check("NOCLIP", noclip, set_noclip)
	_check("SHOW FPS", SettingsManager.show_fps, set_show_fps)
	_check("SHOW TRIGGERS", triggers_shown, set_show_triggers)
	_check("AI ON", ai_enabled, set_ai)
	var items := level_items()
	if not items.is_empty():
		_heading("GIVE ITEMS")
		for p in items:
			_button("GIVE  %s" % p.display_name, give_item.bind(p.item_id, p.display_name))


func _process(_delta: float) -> void:
	if not is_open:
		return
	var player := _player()
	_status.text = "%d FPS   %s" % [Engine.get_frames_per_second(),
		("pos %.1f, %.1f, %.1f" % [player.global_position.x, player.global_position.y, player.global_position.z]) if player else "no player"]


func _build() -> void:
	var theme: Theme = load("res://ui/themes/vcr_theme.tres")
	_panel = PanelContainer.new()
	_panel.theme = theme
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -WIDTH - 16.0
	_panel.offset_right = -16.0
	_panel.offset_top = 16.0
	_panel.offset_bottom = -16.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.05, 0.88)
	bg.border_color = Color(1, 1, 1, 0.25)
	bg.set_border_width_all(1)
	bg.set_content_margin_all(14)
	_panel.add_theme_stylebox_override(&"panel", bg)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DEBUG   [F1]"
	title.add_theme_font_size_override(&"font_size", 26)
	box.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 18)
	_status.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 18)
	l.modulate = Color(0.6, 0.85, 1.0, 0.8)
	_list.add_child(l)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override(&"font_size", 20)
	b.pressed.connect(action)
	_list.add_child(b)
	return b


func _check(text: String, on: bool, setter: Callable) -> void:
	var b := CheckButton.new()
	b.text = text
	b.button_pressed = on
	b.add_theme_font_size_override(&"font_size", 20)
	b.toggled.connect(setter)
	_list.add_child(b)


func _draw_triggers() -> void:
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		return
	_trigger_root = Node3D.new()
	_trigger_root.name = "DebugTriggers"
	scene.add_child(_trigger_root)
	for area in scene.find_children("*", "Area3D", true, false):
		var color := Color(1, 0.25, 0.2, 0.18)
		if area is Checkpoint:
			color = Color(0.3, 1, 0.4, 0.18)
		elif area is HidingSpot:
			color = Color(0.3, 0.5, 1, 0.2)
		elif area.get_script() and String(area.get_script().resource_path).contains("acoustic"):
			color = Color(0.8, 0.8, 0.8, 0.04)
		for shape_node in area.find_children("*", "CollisionShape3D", false, false):
			var cs := shape_node as CollisionShape3D
			var mesh: Mesh = null
			if cs.shape is BoxShape3D:
				var bm := BoxMesh.new()
				bm.size = (cs.shape as BoxShape3D).size
				mesh = bm
			elif cs.shape is SphereShape3D:
				var sm := SphereMesh.new()
				sm.radius = (cs.shape as SphereShape3D).radius
				sm.height = sm.radius * 2.0
				mesh = sm
			elif cs.shape is CylinderShape3D:
				var cm := CylinderMesh.new()
				cm.top_radius = (cs.shape as CylinderShape3D).radius
				cm.bottom_radius = cm.top_radius
				cm.height = (cs.shape as CylinderShape3D).height
				mesh = cm
			if mesh == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.no_depth_test = true
			mat.albedo_color = color
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_trigger_root.add_child(mi)
			mi.global_transform = cs.global_transform
			var label := Label3D.new()
			label.text = String(area.name)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.pixel_size = 0.004
			label.modulate = Color(color.r, color.g, color.b, 0.9)
			mi.add_child(label)


func _on_scene_changed() -> void:
	# per-level toggles don't carry over; noclip and AI reset with the new player / NPCs
	if triggers_shown:
		_trigger_root = null
		triggers_shown = false
	noclip = false
	ai_enabled = true
	if is_open:
		rebuild()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
