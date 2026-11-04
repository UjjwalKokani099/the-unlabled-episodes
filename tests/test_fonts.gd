extends SceneTree
# Every symbol the game prints must exist in the bundled fonts: the iPad web build has no
# system fallback fonts, so a missing glyph shows as an empty box there. Scans every .gd,
# .tscn, .tres and data .json for characters past U+00FF and checks the UI and VCR fonts
# (with their DejaVu symbol fallback) have each one.
# Run: <console exe> --headless --path . --script res://tests/test_fonts.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() in ["gd", "tscn", "json"]:
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with(".") or sub in ["_build", "addons"]:
			continue
		files(dir.path_join(sub), out)


func _initialize() -> void:
	var paths := []
	for root_dir in ["res://ui", "res://systems", "res://chapters", "res://core", "res://player", "res://data"]:
		files(root_dir, paths)
	var used := {}
	for p in paths:
		var text := FileAccess.get_file_as_string(p)
		for i in text.length():
			var c := text.unicode_at(i)
			# symbols and punctuation past Latin-1; Devanagari (0900-097F) is Mukta's own
			if c > 0xFF and not (c >= 0x900 and c <= 0x97F) and not (c >= 0xFE00 and c <= 0xFE0F):
				used[c] = p
	for font_path in ["res://assets/fonts/ui.tres", "res://assets/fonts/vcr.tres", "res://assets/fonts/ui_bold.tres"]:
		var font: Font = load(font_path)
		var missing := []
		for c in used:
			if not font.has_char(c):
				missing.append("%s (U+%04X, %s)" % [String.chr(c), c, String(used[c]).get_file()])
		check(missing.is_empty(), "%s covers %d symbols %s" % [font_path.get_file(), used.size(), missing])
	print("RESULT fails=%d" % fails)
	quit()
