extends Node
## Scene changes, registered as the autoload "SceneLoader". Every level change goes through
## change_scene(): fade to the VCR card (TapeTransition), load the next scene in the
## background (ResourceLoader threaded request, so the game never freezes; the web build
## has no threads and loads directly), swap, optional `prepare` callback (e.g. place the
## player at a checkpoint), hold the card briefly, fade back in. Titled cards are the
## loading screen: reels + progress + a tip from data/loading_tips.json (LoadingTips).

signal transition_started(path: String)
signal transition_finished

## Hold time for a title card (long enough to read the tip) / a plain fade.
const TITLE_CARD_SECONDS := 2.0
const PLAIN_FADE_SECONDS := 0.25

var _transitioning: bool = false
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
	var hold := PLAIN_FADE_SECONDS if lines.is_empty() else TITLE_CARD_SECONDS
	await tree.create_timer(hold, true).timeout
	tree.paused = false
	await _transition.reveal()
	_transitioning = false
	transition_finished.emit()
	EventBus.scene_transition_finished.emit(path)


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
