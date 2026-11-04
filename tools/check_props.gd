extends SceneTree
# Floating-prop audit for one level (tools/prop_audit.gd). Exit code 1 if anything floats.
# Run: <console exe> --headless --path . --script res://tools/check_props.gd -- <scene.tscn>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://chapters/chapter_01/shanti_vihar.tscn"
	await process_frame
	var lv: Node = load(path).instantiate()
	root.add_child(lv)
	for i in 4:
		await physics_frame
	var found: PackedStringArray = load("res://tools/prop_audit.gd").floating(lv)
	for line in found:
		print("FLOATING ", line)
	print("%d floating props in %s" % [found.size(), path])
	lv.queue_free()
	await process_frame
	quit(1 if found.size() > 0 else 0)
