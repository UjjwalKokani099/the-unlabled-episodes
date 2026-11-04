extends Node
## Scene changes, registered as the autoload "SceneLoader". Every level change goes through
## change_scene(): fade to the VCR card (TapeTransition), load the next scene in the
## background (ResourceLoader threaded request, so the game never freezes; the web build
## has no threads and loads directly), swap, optional `prepare` callback (e.g. place the
## player at a checkpoint), hold the card briefly, fade back in. Titled cards are the
## loading screen: reels + progress + a tip from data/loading_tips.json (LoadingTips).
## While the card still covers the screen, every material in the new scene is drawn once on
## a tiny quad in front of the camera (shader warm-up), so nothing hitches on first sight.

signal transition_started(path: String)
signal transition_finished

## Hold time for a title card (long enough to read the tip) / a plain fade.
const TITLE_CARD_SECONDS := 2.0
const PLAIN_FADE_SECONDS := 0.25

## Most materials warmed per load (a level with more just warms the first ones).
const WARMUP_LIMIT := 600

var _transitioning: bool = false
## Materials drawn by the last warm-up (tests, debug overlay).
var last_warmup_count: int = 0
var _transition: TapeTransition


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transition = TapeTransition.new()
	add_child(_transition)


func is_transitioning() -> bool:
	return _transitioning


## The VCR card overlay (other systems may want to cover the screen with it).
func transition() -> TapeTransition:
	return _transition


## Fades out to a card (`header` top-left, `lines` centred; no lines = a plain fade), loads
## `path`, calls `prepare` once the new scene is in the tree, then fades in. Await it.
func change_scene(path: String, header: String = "", lines: PackedStringArray = PackedStringArray(),
		prepare: Callable = Callable()) -> void:
	if _transitioning:
		return
	_transitioning = true
	transition_started.emit(path)
	EventBus.scene_transition_started.emit(path)
	var tree := get_tree()
	tree.paused = true
	if not OS.has_feature("web"):
		ResourceLoader.load_threaded_request(path, "PackedScene", true)
	await _transition.cover(header, lines, LoadingTips.pick(path) if not lines.is_empty() else "")
	var packed := await _finish_loading(path)
	if packed == null:
		push_error("SceneLoader: could not load %s" % path)
		tree.paused = false
		await _transition.reveal()
		_transitioning = false
		return
	tree.change_scene_to_packed(packed)
	await tree.scene_changed
	if prepare.is_valid():
		prepare.call()
	await _warm_up(tree.current_scene)
	var hold := PLAIN_FADE_SECONDS if lines.is_empty() else TITLE_CARD_SECONDS
	await tree.create_timer(hold, true).timeout
	tree.paused = false
	await _transition.reveal()
	_transitioning = false
	transition_finished.emit()
	EventBus.scene_transition_finished.emit(path)


## Draws each material of `scene` once, off to the side of nothing: a grid of 2 cm quads
## half a metre in front of the active camera, for two frames, behind the opaque card.
func _warm_up(scene: Node) -> void:
	last_warmup_count = 0
	if scene == null or DisplayServer.get_name() == "headless":
		return
	var camera := scene.get_viewport().get_camera_3d()
	if camera == null:
		return
	var materials := {}
	for node in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		for m: Material in [gi.material_override, gi.material_overlay]:
			if m:
				materials[m] = true
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			mesh = mi.mesh
			for i in mi.get_surface_override_material_count():
				var o := mi.get_surface_override_material(i)
				if o:
					materials[o] = true
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh:
			for i in mesh.get_surface_count():
				var sm := mesh.surface_get_material(i)
				if sm:
					materials[sm] = true
		if materials.size() >= WARMUP_LIMIT:
			break
	var rig := Node3D.new()
	camera.add_child(rig)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var i := 0
	for m: Material in materials:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3((i % 24 - 12) * 0.021, (i / 24 - 12) * 0.021, -0.5)
		rig.add_child(mi)
		i += 1
	last_warmup_count = i
	for f in 2:
		await get_tree().process_frame
	rig.queue_free()


func _finish_loading(path: String) -> PackedScene:
	if OS.has_feature("web"):
		var direct := load(path) as PackedScene
		_transition.set_progress(1.0)
		return direct
	var progress: Array = []
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_transition.set_progress(progress[0] if not progress.is_empty() else 0.0)
		await get_tree().process_frame
	_transition.set_progress(1.0)
	return ResourceLoader.load_threaded_get(path) as PackedScene
