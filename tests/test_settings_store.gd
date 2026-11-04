extends SceneTree
# Settings store: input actions exist, Settings saves + reloads + drives audio buses, and a
# CUSTOM graphics setup (preset + details) survives a reload.
# Run: <console exe> --headless --path . --script res://tests/test_settings_store.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		fails += 1
		print("FAIL ", msg)

func _initialize() -> void:
	await process_frame
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "flashlight", "interact", "pause"]:
		check(InputMap.has_action(a) and InputMap.action_get_events(a).size() > 0, "action " + a)

	var s: Node = root.get_node("SettingsManager")
	check(AudioServer.get_bus_index("SFX") != -1, "SFX bus exists")
	var old_sens: float = s.mouse_sensitivity
	var old_vol: float = s.sfx_volume
	s.mouse_sensitivity = 0.33
	s.sfx_volume = 0.5
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.5)) < 0.01, "sfx volume applied to bus")
	s.mouse_sensitivity = 50.0
	check(is_equal_approx(s.mouse_sensitivity, 1.0), "sensitivity clamped")
	s.mouse_sensitivity = 0.33
	await process_frame  # deferred save runs
	check(FileAccess.file_exists("user://settings.cfg"), "settings file written")
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	check(is_equal_approx(cfg.get_value("settings", "mouse_sensitivity", -1.0), 0.33), "saved value is 0.33")
	# Change in memory only, then reload from disk.
	s._loading = true
	s.mouse_sensitivity = 0.9
	s._loading = false
	s.load_settings()
	check(is_equal_approx(s.mouse_sensitivity, 0.33), "load_settings restores 0.33 from disk")
	# CUSTOM graphics survive a reload (details are saved, the preset isn't re-applied)
	var old_gfx := {"graphics_quality": s.graphics_quality, "shadow_quality": s.shadow_quality, "fog_quality": s.fog_quality,
		"render_scale": s.render_scale}
	s.graphics_quality = 2
	s.shadow_quality = 0
	await process_frame
	s.load_settings()
	check(s.graphics_quality == s.QUALITY_CUSTOM and s.shadow_quality == 0 and s.fog_quality == 2, "CUSTOM graphics reload as saved")
	for k in old_gfx:
		s.set(k, old_gfx[k])
	# restore user's values
	s.mouse_sensitivity = old_sens
	s.sfx_volume = old_vol
	await process_frame
	print("RESULT fails=", fails)
	quit(fails)
