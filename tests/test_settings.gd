extends SceneTree
# Settings (studio spec step 4): graphics presets fill the detail settings and a changed
# detail turns the preset into CUSTOM; GraphicsManager applies the details and the post
# switches (grain, aberration, vignette, tape blur) to the film grade and VHS shaders;
# reduce flashing; mono audio; key rebind swaps on conflict and resets; gamepad map + right
# stick look with controller sensitivity; hiding objectives; the six-tab menu, brightness
# calibration. Restores every setting it touches.
# Run: <console exe> --path . --quit-after 6000 --script res://tests/test_settings.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	await process_frame
	var settings = root.get_node("SettingsManager")
	var graphics = root.get_node("GraphicsManager")
	var input = root.get_node("InputManager")
	var saved := {}
	for k in settings.KEYS:
		saved[k] = settings.get(k)
	settings.ps1_mode = false

	# --- presets <-> details
	settings.graphics_quality = 2
	check(settings.shadow_quality == 2 and settings.effects_quality == 2 and is_equal_approx(settings.render_scale, 0.9),
		"HIGH preset fills the details")
	settings.shadow_quality = 0
	check(settings.graphics_quality == settings.QUALITY_CUSTOM, "changing a detail -> CUSTOM")
	settings.shadow_quality = 2
	check(settings.graphics_quality == 2, "detail back to the preset's value -> HIGH again")
	settings.graphics_quality = 0
	check(settings.fog_quality == 0 and settings.anti_aliasing == 0, "LOW preset")
	await frames(1)
	check(is_equal_approx(root.scaling_3d_scale, 0.6), "render scale applied (%.2f)" % root.scaling_3d_scale)
	settings.anti_aliasing = 3
	check(root.msaa_3d == Viewport.MSAA_4X, "MSAA 4x applied")
	settings.texture_quality = 2
	check(root.anisotropic_filtering_level == Viewport.ANISOTROPY_16X, "texture quality -> 16x anisotropic")

	# --- post-processing switches
	var room: Node = load("res://tests/scenes/test_room.tscn").instantiate()
	root.add_child(room)
	await frames(10)
	var grade: ShaderMaterial = graphics._grade.material
	var vhs: ShaderMaterial = room.get_node("Camcorder").vhs.material
	settings.film_grain = false
	settings.chromatic_aberration = false
	settings.vignette = false
	settings.tape_blur = false
	check(grade.get_shader_parameter("grain") == 0.0 and grade.get_shader_parameter("fringe_px") == 0.0
		and grade.get_shader_parameter("vignette") == 0.0, "film grade: grain, fringe, vignette off")
	check(vhs.get_shader_parameter("noise_amount") == 0.0 and vhs.get_shader_parameter("aberration_px") == 0.0
		and vhs.get_shader_parameter("vignette") == 0.0 and vhs.get_shader_parameter("bleed") == 0.0, "VHS: noise, split, vignette, blur off")
	settings.film_grain = true
	settings.chromatic_aberration = true
	check(grade.get_shader_parameter("grain") > 0.0 and vhs.get_shader_parameter("aberration_px") > 0.0, "and back on")

	# --- reduce flashing
	var cam = room.get_node("Camcorder")
	settings.reduce_flashing = true
	cam.vhs._glitch = 0.0
	cam.glitch(1.0, 0.5)
	check(cam.vhs.get_glitch() < 0.4, "reduce flashing: glitch spikes scaled down (%.2f)" % cam.vhs.get_glitch())
	cam.show_static(false)
	check(cam._static.modulate.r < 0.6, "reduce flashing: static dimmed")
	cam.hide_static()
	settings.reduce_flashing = false

	# --- mono
	settings.mono_audio = true
	var mono_on := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectStereoEnhance:
			mono_on = AudioServer.is_bus_effect_enabled(0, i)
	check(mono_on, "mono audio folds the master bus")
	settings.mono_audio = false

	# --- rebinding
	var saved_keys: Dictionary = settings.key_bindings.duplicate()
	var crouch_key: int = settings.physical_key_of(&"crouch")
	var swapped: StringName = settings.rebind(&"flashlight", crouch_key)
	check(swapped == &"crouch" and settings.physical_key_of(&"flashlight") == crouch_key and settings.physical_key_of(&"crouch") != crouch_key,
		"rebinding onto a used key swaps the two (%s)" % swapped)
	settings.reset_bindings()
	check(settings.physical_key_of(&"crouch") == crouch_key and settings.key_bindings.is_empty(), "reset restores default keys")

	# --- gamepad
	var has_pad := func(action: StringName, cls: String) -> bool:
		for e in InputMap.action_get_events(action):
			if e.get_class() == cls:
				return true
		return false
	check(has_pad.call(&"interact", "InputEventJoypadButton") and has_pad.call(&"move_forward", "InputEventJoypadMotion")
		and has_pad.call(&"look_right", "InputEventJoypadMotion"), "gamepad map present (also after reset)")
	var p = room.get_node("Player")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_UP
	pad.pressed = true
	Input.parse_input_event(pad)
	await frames(2)
	input.capture_mouse(true)
	settings.controller_sensitivity = 1.0
	var yaw0: float = p.rotation.y
	Input.action_press(&"look_right", 1.0)
	await create_timer(0.5).timeout
	var turned1: float = absf(angle_difference(yaw0, p.rotation.y))
	settings.controller_sensitivity = 2.0
	yaw0 = p.rotation.y
	await create_timer(0.5).timeout
	var turned2: float = absf(angle_difference(yaw0, p.rotation.y))
	Input.action_release(&"look_right")
	check(turned1 > deg_to_rad(30.0), "right stick turns the view (%.0f deg in 0.5 s)" % rad_to_deg(turned1))
	check(turned2 > turned1 * 1.6, "controller sensitivity 2x turns faster (%.0f deg)" % rad_to_deg(turned2))

	# --- objectives hidden
	var panel = room.get_node("HUD/Objectives")
	settings.show_objectives = false
	panel._on_changed()
	await create_timer(0.4).timeout
	check(panel.modulate.a < 0.01, "objectives off: no automatic popup")
	settings.show_objectives = true
	room.queue_free()
	await frames(3)

	# --- the menu
	var sm = load("res://ui/menus/settings_menu.tscn").instantiate()
	root.add_child(sm)
	await frames(2)
	sm.open()
	check(sm._tabs.tab_count == 6, "six tabs")
	var missing := []
	for row in sm.ROWS:
		if not sm.controls.has(row.get("key", row.get("button"))):
			missing.append(row.get("key", row.get("button")))
	check(missing.is_empty(), "every setting has a control %s" % [missing])
	settings.graphics_quality = 1
	sm.show_tab(sm.tab_index("GRAPHICS"))
	sm.controls[&"fog_quality"].value = 2
	await frames(1)
	check(sm._value_labels[&"graphics_quality"].text == "CUSTOM", "menu: changing fog shows preset CUSTOM")
	sm.controls[&"graphics_quality"].value = 0
	await frames(1)
	check(sm._value_labels[&"fog_quality"].text == "LOW", "menu: picking LOW moves the detail rows")
	sm.show_tab(sm.tab_index("DISPLAY"))
	sm.controls[&"calibrate"].pressed.emit()
	await frames(1)
	check(sm.calibration.visible, "calibrate opens the brightness overlay")
	sm.calibration.slider.value = 1.2
	check(is_equal_approx(settings.brightness, 1.2), "calibration slider sets brightness")
	sm.close()
	check(not sm.calibration.visible and sm.visible, "Esc ends calibration first, settings stay open")
	sm.close()
	check(not sm.visible, "second Esc closes settings")
	sm.queue_free()

	settings.key_bindings = saved_keys
	for k in saved:
		settings.set(k, saved[k])
	await frames(3)
	print("RESULT fails=%d" % fails)
	quit()
