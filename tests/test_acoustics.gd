extends SceneTree
# Acoustics: AcousticZones retune the SFX bus "Space" reverb to where the player stands
# (cabin, courtyard, stairwell, empty flat 4B, meter room; the hub room and corridor),
# the innermost zone wins, and tube lights hum only while lit (power cut = silence).
# Separate save file. Run: <console exe> --path . --quit-after 20000 --script res://tests/test_acoustics.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func wet() -> float:
	var bus := AudioServer.get_bus_index(&"SFX")
	return (AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb).wet


func space() -> StringName:
	return load("res://scripts/audio/acoustic_zone.gd").current_space()


func stand(p, pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await physics(8)
	await create_timer(1.0).timeout  # the reverb eases over 0.8 s


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.delete_save()
	var bus := AudioServer.get_bus_index(&"SFX")
	check(bus >= 0 and AudioServer.get_bus_effect(bus, 0) is AudioEffectReverb, "SFX bus has the Space reverb")

	check(game.start_chapter(&"tape_01_watchman"), "tape 1 starts")
	await game.transition_finished
	var lv: Node = current_scene
	lv.get_node("Story").time_scale = 0.01
	var p = get_first_node_in_group("player")
	await stand(p, Vector3(5.75, 0.05, 23.6))
	check(space() == &"hard_room", "spawn in the cabin: hard room (inside the courtyard zone, the cabin wins) - %s" % space())
	check(absf(wet() - 0.24) < 0.03, "reverb eased to the cabin's (wet %.2f)" % wet())
	await stand(p, Vector3(0, 0.05, 10))
	check(space() == &"yard", "courtyard: slap-back between the wings - %s" % space())
	await stand(p, Vector3(-12.5, 0.05, -15.0))
	check(space() == &"stair", "B wing stairs: long concrete tail - %s" % space())
	check(wet() > 0.3, "stairwell reverb is the wettest (%.2f)" % wet())
	await stand(p, Vector3(-7, 12.05, -16.5))
	check(space() == &"empty_room", "inside 4B: an empty flat echoes - %s" % space())
	await stand(p, Vector3(28, 0.05, -4))
	check(space() == &"hard_room", "meter room - %s" % space())
	await stand(p, Vector3(-28, 0.05, 24))
	check(space() == &"yard", "back out in the compound - %s" % space())

	# tube lights hum while lit; the power cut silences them
	var tube = lv.get_node("CabinTube")
	var hum: AudioStreamPlayer3D = tube.get_node("Hum")
	check(hum.playing, "the cabin's tube light hums")
	lv.get_node("Power").cut()
	await physics(3)
	check(not hum.playing, "power cut: the hum stops")
	lv.get_node("Power").restore()
	await create_timer(1.0).timeout
	check(hum.playing, "power back: humming again after the choke's stutter")

	# the hub
	game.enter_hub()
	await game.transition_finished
	p = get_first_node_in_group("player")
	await stand(p, Vector3(1.6, 0.05, 1.4))
	check(space() == &"small_room", "Nikhil's room: small furnished room - %s" % space())
	await stand(p, Vector3(1.8, 0.05, 5.2))
	check(space() == &"corridor", "the corridor outside - %s" % space())

	game.delete_save()
	game.save_path = "user://save.json"
	current_scene.queue_free()
	await physics(2)
	print("RESULT fails=%d" % fails)
	quit()
