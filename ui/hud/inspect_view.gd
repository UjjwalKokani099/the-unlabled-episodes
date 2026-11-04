class_name InspectView
extends CanvasLayer
## Close-up of an Inspectable, held in front of the camera: a copy of its Model is shown in
## a small lit 3D stage of its own. Drag (or arrow keys / WASD) to turn it, scroll to zoom.
## E takes it (if it can be taken) or puts it back; Esc / right-click puts it back.
## Lives in the HUD: get_tree().call_group("hud", "inspect", inspectable)

signal closed

const RUSTLE := preload("res://assets/audio/sfx/rustle.wav")
## Largest side of the item as shown, in metres of the little stage.
const SHOW_SIZE := 0.36
const TURN_SPEED := 0.008
const KEY_TURN := 2.2

const BLUR_SHADER := preload("res://assets/shaders/ui_blur.gdshader")

var is_open: bool = false
var _item: Inspectable
var _pivot: Node3D
var _camera: Camera3D
var _zoom: float = 1.0
var _root: Control
var _title: Label
var _text: Label
var _hint: Label
var _sound: AudioStreamPlayer
var _dragging: bool = false


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


## Shows `item` close up.
func open(item: Inspectable) -> void:
	if is_open:
		return
	_item = item
	for child in _pivot.get_children():
		child.queue_free()
	var copy := _visual_copy(item.model)
	_pivot.add_child(copy)
	_fit(copy)
	_pivot.rotation = Vector3(0.35, 0.6, 0.0)
	_zoom = 1.0
	_title.text = item.title
	_text.text = item.description
	_hint.text = ("[E] Take    [Esc] Put back" if item.can_take() else "[E] / [Esc] Put back") \
		+ "    Drag or WASD to turn  ·  Scroll to zoom"
	_root.visible = true
	is_open = true
	_set_player_input(false)
	InputManager.capture_mouse(false)
	_sound.play()


## Closes the view; `take` = the player took the item.
func close(take: bool = false) -> void:
	if not is_open:
		return
	_root.visible = false
	is_open = false
	_dragging = false
	_set_player_input(true)
	InputManager.capture_mouse(true)
	if take and is_instance_valid(_item):
		_item.take()
	_item = null
	_sound.play()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"interact"):
		close(is_instance_valid(_item) and _item.can_take())
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		close(false)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			close(false)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = clampf(_zoom - 0.1, 0.5, 1.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = clampf(_zoom + 0.1, 0.5, 1.6)
	elif event is InputEventMouseMotion and _dragging:
		turn((event as InputEventMouseMotion).relative * TURN_SPEED)


## Turns the item (x = around the vertical axis, y = tip towards/away).
func turn(amount: Vector2) -> void:
	_pivot.rotate(Vector3.UP, amount.x)
	_pivot.rotate(Vector3.RIGHT, amount.y)


func _process(delta: float) -> void:
	if not is_open:
		return
	var keys := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if keys != Vector2.ZERO:
		turn(keys * KEY_TURN * delta)
	_camera.position.z = lerpf(_camera.position.z, _zoom, 1.0 - exp(-12.0 * delta))


## A copy of the model with only the visible parts (no scripts, bodies or sounds).
func _visual_copy(model: Node3D) -> Node3D:
	var copy := model.duplicate(0) as Node3D  # 0 = no signals, groups or scripts
	copy.transform = Transform3D.IDENTITY
	_strip(copy)
	return copy


func _strip(node: Node) -> void:
	for child in node.get_children():
		var keep: bool = child is Node3D and not (child is CollisionObject3D or child is AudioStreamPlayer3D
			or child is CollisionShape3D or child is Light3D)
		if keep:
			_strip(child)
		else:
			node.remove_child(child)
			child.queue_free()


## Centres the copy on the pivot and scales it so its largest side is SHOW_SIZE.
func _fit(copy: Node3D) -> void:
	var box := _bounds(copy, Transform3D.IDENTITY)
	if box.size == Vector3.ZERO:
		return
	var s := SHOW_SIZE / maxf(box.size.x, maxf(box.size.y, box.size.z))
	copy.scale = Vector3.ONE * s
	copy.position = -box.get_center() * s


func _bounds(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.get_children():
		if not child is Node3D:
			continue
		var t := xform * (child as Node3D).transform
		var part := AABB()
		var has := false
		if child is VisualInstance3D:
			part = t * (child as VisualInstance3D).get_aabb()
			has = true
		var inner := _bounds(child, t)
		if inner.size != Vector3.ZERO:
			part = part.merge(inner) if has else inner
			has = true
		if has:
			box = part if first else box.merge(part)
			first = false
	return box


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# The world behind stays visible, blurred and darkened (assets/shaders/ui_blur.gdshader).
	var dim := ColorRect.new()
	var blur := ShaderMaterial.new()
	blur.shader = BLUR_SHADER
	dim.material = blur
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	# The little stage: own world, own lights, transparent background.
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	container.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.1
	key.light_color = Color(1, 0.94, 0.84)  # torch-warm
	viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.6, 0.4, -0.5)
	rim.light_energy = 0.6
	rim.omni_range = 3.0
	viewport.add_child(rim)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	_camera.position = Vector3(0, 0, 1.0)
	viewport.add_child(_camera)
	# Text: name, description, controls.
	# Text sits at the top: the bottom of the screen belongs to subtitles.
	_title = _label(34, Vector2(0.5, 0.06))
	_text = _label(22, Vector2(0.5, 0.13))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 900
	_text.offset_left = -450
	_text.offset_right = 450
	_hint = _label(18, Vector2(0.5, 0.93))
	_hint.modulate = Color(1, 1, 1, 0.6)
	_sound = AudioStreamPlayer.new()
	_sound.stream = RUSTLE
	_sound.bus = &"SFX"
	_sound.volume_db = -6.0
	add_child(_sound)


func _label(size: int, anchor: Vector2) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.anchor_left = anchor.x
	label.anchor_right = anchor.x
	label.anchor_top = anchor.y
	label.anchor_bottom = anchor.y
	label.offset_left = -600
	label.offset_right = 600
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label


func _set_player_input(enabled: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_enabled = enabled
