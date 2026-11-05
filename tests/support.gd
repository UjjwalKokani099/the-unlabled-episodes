extends RefCounted
# Shared test teardown (bug B-003): tests used to quit a few frames after queue_free() of the
# level while sounds, tweens, threaded nav bakes and deferred calls still held references,
# so Godot reported leaked ObjectDB instances at exit. finish() does what GameManager.quit_game
# does for the real game, waits for background work, then quits with the test's result.
#   await load("res://tests/support.gd").finish(self, fails)


static func finish(tree: SceneTree, fails: int) -> void:
	print("RESULT fails=", fails)
	tree.paused = false
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio and audio.has_method("shutdown"):
		audio.shutdown()
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for node in tree.root.find_children("*", type, true, false):
			node.call(&"stop")
	# a nav mesh still baking on its thread keeps the level alive
	for region in tree.root.find_children("*", "NavigationRegion3D", true, false):
		var guard := 0
		while (region as NavigationRegion3D).is_baking() and guard < 600:
			await tree.process_frame
			guard += 1
	# overlays added to the root by the game (END OF TAPE card, transition layers)
	for child in tree.root.get_children():
		if child is CanvasLayer and child.get_script() and String(child.get_script().resource_path).contains("chapter_complete"):
			child.queue_free()
	if tree.current_scene:
		tree.current_scene.queue_free()
	for i in 6:
		await tree.process_frame
	tree.quit(fails)
