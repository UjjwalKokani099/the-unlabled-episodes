class_name PlayerPhone
extends Node3D
## Nikhil's phone (studio spec: a diegetic phone the player can raise: texts, calls, time,
## battery, torch; its screen is a real-time UI in a SubViewport on the 3D model).
## Present day only (story: the hub, later the 2009 tape); Tape 1 (1998) never gets one.
##
##   var phone := PlayerPhone.attach(player, "res://data/phone/hub.json", stage)
##   phone.carried = true          # taken from the desk; false = lying somewhere (desk_anchor)
##
## R (`phone`) raises / lowers it while carried. Raised: up/down or the mouse wheel moves
## the highlight, E selects, right click / Backspace goes back; touches on the glass tap
## rows. Walking stays possible (no running); the world can't be used while it's up.
## Texts and calls from the data file's "incoming" list arrive while in the room; the phone
## buzzes (from the desk when not carried). Battery: GameManager memory "phone_battery",
## drains while raised, charges while `charging`.

signal raised_changed(raised: bool)

const BODY_MESH := preload("res://assets/models/phone/phone_body.obj")
const BUZZ := preload("res://assets/audio/sfx/phone_buzz.wav")
const RING := preload("res://assets/audio/sfx/mobile_ring.wav")
const LOWERED := Vector3(0.14, -0.42, -0.24)
const RAISED := Vector3(0.062, 0.014, -0.175)
const SCREEN_SIZE := Vector2(0.064, 0.137)
const DRAIN_PER_SECOND := 1.0 / 900.0
const CHARGE_PER_SECOND := 1.0 / 240.0

var player: Player
var screen: PhoneScreen
var carried: bool = false:
	set(value):
		carried = value
		if not carried and raised:
			lower()
var charging: bool = false:
	set(value):
		charging = value
		if screen:
			screen.charging = value
## Where the phone lies when not carried (buzzes come from there).
var desk_anchor: Node3D
var raised: bool = false
var stage: int = 0

var _viewport: SubViewport
var _screen_quad: MeshInstance3D
var _tween: Tween
var _ring: AudioStreamPlayer
var _incoming: Array = []
var _room_time: float = 0.0


## Puts a phone in `player`'s hand (lowered, out of sight) with the data for this place.
static func attach(p: Player, data_path: String, hub_stage: int) -> PlayerPhone:
	var phone := PlayerPhone.new()
	phone.name = "Phone"
	phone.player = p
	phone.stage = hub_stage
	p.camera.add_child(phone)
	phone.load_data(data_path)
	p.phone = phone
	return phone


func _ready() -> void:
	position = LOWERED
	visible = false
	var body := MeshInstance3D.new()
	body.mesh = BODY_MESH
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.085, 0.1)
	mat.metallic = 0.6
	mat.roughness = 0.35
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	_viewport = SubViewport.new()
	_viewport.size = PhoneScreen.SIZE
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	screen = PhoneScreen.new()
	_viewport.add_child(screen)
	screen.battery = clampf(float(GameManager.remembered_value("phone_battery", 0.34)), 0.0, 1.0)
	screen.torch_requested.connect(_toggle_torch)
	screen.call_answered.connect(_on_call_answered)
	screen.call_declined.connect(func(_c: String) -> void: _stop_ring())
	_screen_quad = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	_screen_quad.mesh = quad
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_texture = _viewport.get_texture()
	smat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_screen_quad.material_override = smat
	_screen_quad.position = Vector3(0, 0, 0.0042)
	_screen_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_screen_quad)
	_ring = AudioStreamPlayer.new()
	_ring.stream = RING
	_ring.bus = &"SFX"
	_ring.volume_db = -8.0
	_ring.finished.connect(func() -> void:
		if screen.is_ringing():
			_ring.play())
	add_child(_ring)


func load_data(path: String) -> void:
	var data := screen.load_data(path, stage) if screen else {}
	_incoming = (data.get("incoming", []) as Array).filter(
		func(e: Dictionary) -> bool: return PhoneScreen._in_stage(e, stage))


func is_raised() -> bool:
	return raised


func raise() -> void:
	if raised or not carried:
		return
	raised = true
	visible = true
	_move_to(RAISED, Vector3(deg_to_rad(4), deg_to_rad(-6), deg_to_rad(-2)), 0.32)
	InputManager.capture_mouse(not InputManager.touch_mode)
	EventBus.fire(&"phone_raised")
	raised_changed.emit(true)


func lower() -> void:
	if not raised:
		return
	raised = false
	_move_to(LOWERED, Vector3(deg_to_rad(40), 0, 0), 0.28)
	_tween.tween_callback(func() -> void: visible = raised)
	raised_changed.emit(false)


func _move_to(pos: Vector3, rot: Vector3, seconds: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", pos, seconds)
	_tween.tween_property(self, "rotation", rot, seconds)
	_tween.chain()


func _process(delta: float) -> void:
	_room_time += delta
	for entry: Dictionary in _incoming.duplicate():
		if _room_time >= float(entry.get("after", 0.0)):
			_incoming.erase(entry)
			_arrive(entry)
	if screen:
		if charging:
			screen.battery = minf(screen.battery + CHARGE_PER_SECOND * delta, 1.0)
		elif raised:
			screen.battery = maxf(screen.battery - DRAIN_PER_SECOND * delta, 0.01)
		GameManager.remember_value("phone_battery", snappedf(screen.battery, 0.001))
	# a little life in the hand while it's up
	if raised and (_tween == null or not _tween.is_running()):
		var t := Time.get_ticks_msec() / 1000.0
		position = RAISED + Vector3(sin(t * 1.3) * 0.0015, sin(t * 1.9) * 0.0012, 0) * SettingsManager.motion_scale()


func _arrive(entry: Dictionary) -> void:
	match String(entry.get("kind", "")):
		"text":
			screen.receive_text(String(entry.thread), entry.message)
			_buzz()
			if carried and not raised:
				get_tree().call_group("hud", "show_message", "Your phone buzzes. [%s]" % SettingsManager.key_name(&"phone"), 3.0)
		"call":
			screen.ring(String(entry.contact), String(entry.get("dialogue", "")))
			_buzz()
			_ring.play()
			if carried and not raised:
				get_tree().call_group("hud", "show_message", "%s is calling. [%s]" % [
					String(screen.contacts.get(entry.contact, entry.contact)), SettingsManager.key_name(&"phone")], 4.0)


func _buzz() -> void:
	if carried or desk_anchor == null:
		AudioManager.play_sfx(BUZZ, -6.0)
	else:
		AudioManager.play_at(BUZZ, desk_anchor.global_position, -2.0)


func _stop_ring() -> void:
	_ring.stop()


func _toggle_torch() -> void:
	player.toggle_flashlight()
	screen.torch_on = player.flashlight.visible
	screen.show_page(screen.page, screen.page_arg)


func _on_call_answered(_contact: String, dialogue: String) -> void:
	_stop_ring()
	if dialogue == "":
		screen.end_call()
		return
	var view := get_tree().get_first_node_in_group("hud")
	get_tree().call_group("hud", "start_dialogue", dialogue, "")
	var dv: Node = view.get_node_or_null("DialogueView") if view else null
	if dv and dv.has_signal(&"finished"):
		await dv.finished
	if is_inside_tree():
		screen.end_call()


# --- input -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"phone") and not event.is_echo():
		if not carried or not player.input_enabled:
			return
		get_viewport().set_input_as_handled()
		if raised:
			lower()
		else:
			raise()
		return
	if not raised:
		return
	var used := true
	if event.is_action_pressed(&"ui_up") or _wheel(event, MOUSE_BUTTON_WHEEL_UP):
		screen.move(-1)
	elif event.is_action_pressed(&"ui_down") or _wheel(event, MOUSE_BUTTON_WHEEL_DOWN):
		screen.move(1)
	elif event.is_action_pressed(&"interact") or (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not InputManager.touch_mode):
		screen.select()
	elif (event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_BACKSPACE) \
			or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		if not screen.back():
			lower()
	elif event is InputEventScreenTouch and event.pressed:
		var uv := screen_uv_at((event as InputEventScreenTouch).position)
		if uv.x >= 0.0:
			screen.tap_at(uv * Vector2(PhoneScreen.SIZE))
		else:
			used = false
	else:
		used = false
	if used:
		get_viewport().set_input_as_handled()


static func _wheel(event: InputEvent, button: MouseButton) -> bool:
	return event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == button


## Screen UV (0..1, top-left origin) under a viewport position, or (-1, -1) off the glass.
func screen_uv_at(pos: Vector2) -> Vector2:
	var cam := player.camera
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var plane := Plane(_screen_quad.global_basis.z, _screen_quad.global_position)
	var hit: Variant = plane.intersects_ray(from, dir)
	if hit == null:
		return Vector2(-1, -1)
	var local := _screen_quad.to_local(hit as Vector3)
	var uv := Vector2(local.x / SCREEN_SIZE.x + 0.5, 0.5 - local.y / SCREEN_SIZE.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv
