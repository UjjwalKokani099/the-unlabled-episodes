extends SceneTree
# Core autoloads: the six audio buses, pause muffling, UI sounds and the one-shot pools
# (AudioManager); device switching keyboard/gamepad/touch and mouse capture (InputManager);
# typed EventBus signals; SceneLoader availability.
# Run: <console exe> --path . --quit-after 2000 --script res://tests/test_core_managers.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func lowpass_enabled(bus_name: StringName) -> bool:
	var bus := AudioServer.get_bus_index(bus_name)
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			return AudioServer.is_bus_effect_enabled(bus, i)
	return false


func _initialize() -> void:
	await process_frame
	var audio = root.get_node("AudioManager")
	var input = root.get_node("InputManager")
	var bus = root.get_node("EventBus")
	check(root.has_node("SceneLoader") and root.has_node("SaveManager"), "SceneLoader + SaveManager autoloads")

	# --- audio
	for name in ["Master", "Music", "SFX", "Ambience", "Voice", "UI"]:
		check(AudioServer.get_bus_index(name) >= 0, "audio bus %s" % name)
	check(not lowpass_enabled(&"SFX"), "game audio clear while playing")
	audio.set_muffled(true)
	check(lowpass_enabled(&"SFX") and lowpass_enabled(&"Ambience") and lowpass_enabled(&"Voice"), "paused: SFX/Ambience/Voice muffled")
	check(AudioServer.get_bus_index("UI") >= 0 and not lowpass_enabled(&"UI"), "UI stays clear")
	audio.set_muffled(false)
	check(not lowpass_enabled(&"SFX"), "unpaused: clear again")
	audio.play_ui(&"click")
	await process_frame
	check(audio.get_node("UI").playing and audio.get_node("UI").bus == &"UI", "UI click plays on the UI bus")
	var hum: AudioStream = load("res://assets/audio/sfx/room_hum.wav")
	var first = audio.play_sfx(hum, -30.0)
	var second = audio.play_sfx(hum, -30.0)
	check(first != second, "one-shots use different pooled players while busy")
	first.stop()
	second.stop()

	# --- input devices
	var got := []
	var on_device := func(d: int) -> void: got.append(d)
	bus.input_device_changed.connect(on_device)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	Input.parse_input_event(pad)
	await process_frame
	check(input.device == input.Device.GAMEPAD, "gamepad button -> gamepad mode")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(input.device == input.Device.KEYBOARD_MOUSE, "key press -> keyboard/mouse mode")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	check(input.touch_mode, "screen touch -> touch mode")
	input.capture_mouse(true)
	check(input.mouse_captured() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "touch mode: 'playing' without grabbing the mouse")
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	check(got.size() >= 3, "EventBus.input_device_changed fired on each switch (%d)" % got.size())
	bus.input_device_changed.disconnect(on_device)

	# --- typed signals exist
	for sig in ["chapter_started", "chapter_completed", "checkpoint_saved", "scene_transition_started",
			"scene_transition_finished", "setting_changed", "objective_changed", "game_paused"]:
		check(bus.has_signal(sig), "EventBus.%s" % sig)

	input.capture_mouse(false)
	print("RESULT fails=%d" % fails)
	quit()
