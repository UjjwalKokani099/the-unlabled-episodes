extends SceneTree
# Error log (studio spec 15): GameManager installs ErrorLog at start; errors and warnings
# land in user://logs/errors.log with a timestamp and where they came from.
# Run: <console exe> --headless --path . --script res://tests/test_error_log.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	await process_frame
	var log_class = load("res://core/error_log.gd")
	var log = log_class.instance()
	check(log != null, "GameManager installed the error log")
	var before: int = log.count
	push_error("test_error_log: deliberate error %d" % Time.get_ticks_msec())
	push_warning("test_error_log: deliberate warning")
	await process_frame
	check(log.count == before + 2, "an error and a warning were logged (%d)" % (log.count - before))
	var text := FileAccess.get_file_as_string(log_class.PATH)
	var lines := text.split("\n")
	var hit := ""
	for l in lines:
		if l.contains("deliberate error"):
			hit = l
	check(hit != "", "the error is in user://logs/errors.log")
	check(hit.begins_with(Time.get_date_string_from_system()), "with a timestamp: %s" % hit.left(40))
	check(text.contains("WARNING: test_error_log: deliberate warning"), "warnings too")
	check(text.contains("---- session"), "each session starts with a header")
	print("RESULT fails=", fails)
	quit(fails)
