extends SceneTree
# Polish details (studio spec 11, build step 8): irregular noise flicker with a synced
# sound; the CCTV screen lights the cabin and dies with the power; clocks show tape time;
# idle variety after 20 s standing still; no floating props in Tape 1 or the hub.
# Run: <console exe> --path . --quit-after 60000 --script res://tests/test_polish.gd

var fails := 0
var game: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _initialize() -> void:
	await process_frame
	game = root.get_node("GameManager")
	game.save_path = "user://test_polish_save.json"
	game.delete_save()
	var settings = root.get_node("SettingsManager")
	var old_flash = settings.reduce_flashing

	# --- LightFlicker: irregular drop-outs, not a sine
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.0
	root.add_child(lamp)
	var flicker_class = load("res://systems/events/light_flicker.gd")
	var f = flicker_class.new(lamp, 0.04)
	var drops := []
	var was_lit := true
	var lows := 0
	var t := 0.0
	while t < 6.0:
		var k: float = f.level_at(t)
		var lit := k > 0.05
		if was_lit and not lit:
			drops.append(t)
		if not lit:
			lows += 1
		was_lit = lit
		t += 1.0 / 60.0
	var gaps := []
	for i in range(1, drops.size()):
		gaps.append(drops[i] - drops[i - 1])
	var mean := 0.0
	for g in gaps:
		mean += g
	mean /= maxf(gaps.size(), 1)
	var dev := 0.0
	for g in gaps:
		dev += (g - mean) * (g - mean)
	dev = sqrt(dev / maxf(gaps.size(), 1))
	check(drops.size() >= 3, "flicker drops out several times in 6 s (%d)" % drops.size())
	check(gaps.size() >= 2 and dev > mean * 0.25, "gaps between drop-outs are irregular (mean %.2f, sd %.2f)" % [mean, dev])
	check(lows > 0 and lows < 360 * 0.6, "it is mostly lit, with dark moments (%d/360 dark)" % lows)
	settings.reduce_flashing = false
	var pool_before: int = _sfx_playing()
	await flicker_class.run(lamp, 1.5)
	check(is_equal_approx(lamp.light_energy, 2.0), "energy restored after the flicker")
	check(_sfx_played_flicker(), "drop-outs play the flicker tick at the light")
	settings.reduce_flashing = true
	var g2 = flicker_class.new(lamp, 0.04)
	var deepest := 1.0
	var tt := 0.0
	while tt < 4.0:
		g2.step(1.0 / 60.0)
		deepest = minf(deepest, lamp.light_energy / 2.0)
		tt += 1.0 / 60.0
	g2.restore()
	check(deepest > 0.5, "reduce flashing: drop-outs stay shallow (%.2f)" % deepest)
	settings.reduce_flashing = old_flash
	lamp.queue_free()
	check(pool_before >= 0, "audio pool reachable")

	# --- Tape 1: the CCTV glow, the cabin clock, props on the ground
	change_scene_to_file("res://chapters/chapter_01/shanti_vihar.tscn")
	await frames(6)
	var lv: Node = current_scene
	lv.get_node("Story").time_scale = 0.05
	await wait(1.5)
	var cctv = lv.get_node("CCTV")
	check(cctv.glow_energy() > 0.05, "the CCTV screen lights the cabin (%.2f)" % cctv.glow_energy())
	cctv.set_power(false)
	await frames(2)
	check(cctv.glow_energy() == 0.0, "no power: the glow dies with the screen")
	cctv.set_power(true)
	var clock = lv.find_child("WallClock", true, false)
	var camcorder = get_first_node_in_group("camcorder")
	check(clock != null and absi(clock.seconds_now() - camcorder.osd.time_of_day()) <= 1,
		"the cabin clock shows the camcorder's time")
	var audit = load("res://tools/prop_audit.gd")
	var floating: PackedStringArray = audit.floating(lv)
	check(floating.is_empty(), "Tape 1: no floating props %s" % [floating])
	var idle = lv.get_node_or_null("IdleEvents")
	check(idle != null and idle.sounds.size() >= 4, "Tape 1 has idle events")

	# --- idle variety: stand still, something happens; move, the timer resets
	var p = get_first_node_in_group("player")
	idle.idle_seconds = 1.0
	idle.max_tension = 1.0
	var heard := []
	idle.played.connect(func(s) -> void: heard.append(s))
	await wait(1.6)
	check(heard.size() == 1, "standing still: an idle sound plays (%d)" % heard.size())
	check(idle._wait >= idle.cooldown.x, "then a cooldown before the next")
	idle._wait = 0.0
	p.global_position += Vector3(0.5, 0, 0)
	await frames(2)
	check(idle.idle_time < 0.1, "moving resets the idle timer")
	var a = idle.play_one(p)
	var b = idle.play_one(p)
	check(a != b, "never the same sound twice in a row")
	game.block_saving("test")
	idle._wait = 0.0
	idle.idle_time = 5.0
	var n := heard.size()
	await frames(5)
	check(heard.size() == n, "not during a scare / cutscene")
	game.unblock_saving("test")

	# --- the hub
	current_scene.queue_free()
	await frames(3)
	var room: Node3D = load("res://chapters/hub/nikhil_room.tscn").instantiate()
	root.add_child(room)
	for i in 4:
		await physics_frame
	floating = audit.floating(room)
	check(floating.is_empty(), "hub: no floating props %s" % [floating])
	room.queue_free()

	game.delete_save()
	await frames(3)
	print("RESULT fails=", fails)
	quit(fails)


func _sfx_playing() -> int:
	var am = root.get_node("AudioManager")
	var n := 0
	for c in am.find_children("*", "AudioStreamPlayer3D", true, false):
		if c.playing:
			n += 1
	return n


func _sfx_played_flicker() -> bool:
	var am = root.get_node("AudioManager")
	for c in am.find_children("*", "AudioStreamPlayer3D", true, false):
		if c.stream and c.stream.resource_path.ends_with("light_flicker.wav"):
			return true
	return false
