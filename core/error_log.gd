class_name ErrorLog
extends Logger
## Crash/error log (studio spec 15): every engine/script error and warning, with a timestamp
## and the GDScript backtrace when there is one, appended to user://logs/errors.log. Godot's
## own rotating user://logs/godot.log keeps all output; this file is the short list a player
## can send in. Rotates at start-up when it passes MAX_BYTES (keeps KEEP old files).
## GameManager installs it (ErrorLog.install()). Called from any thread: guarded by a mutex.

const PATH := "user://logs/errors.log"
const MAX_BYTES := 512 * 1024
const KEEP := 3

static var _installed: ErrorLog

var _file: FileAccess
var _mutex := Mutex.new()
var count: int = 0


static func install() -> ErrorLog:
	if _installed:
		return _installed
	_installed = ErrorLog.new()
	_installed._open()
	OS.add_logger(_installed)
	return _installed


static func uninstall() -> void:
	if _installed:
		OS.remove_logger(_installed)
		_installed._close()
		_installed = null


static func instance() -> ErrorLog:
	return _installed


func _open() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	if FileAccess.file_exists(PATH) and FileAccess.get_file_as_bytes(PATH).size() > MAX_BYTES:
		for i in range(KEEP - 1, 0, -1):
			var older := "%s.%d" % [PATH, i]
			if FileAccess.file_exists(older):
				DirAccess.rename_absolute(older, "%s.%d" % [PATH, i + 1])
		DirAccess.rename_absolute(PATH, PATH + ".1")
	_file = FileAccess.open(PATH, FileAccess.READ_WRITE if FileAccess.file_exists(PATH) else FileAccess.WRITE)
	if _file:
		_file.seek_end()
		_write("---- session %s  v%s  %s %s" % [Time.get_datetime_string_from_system(), ProjectSettings.get_setting("application/config/version", "?"),
			OS.get_name(), RenderingServer.get_current_rendering_method()])


func _close() -> void:
	_mutex.lock()
	if _file:
		_file.close()
		_file = null
	_mutex.unlock()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind := "WARNING" if error_type == ERROR_TYPE_WARNING else ("SHADER ERROR" if error_type == ERROR_TYPE_SHADER else
		("SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT else "ERROR"))
	var text := "%s %s: %s\n    at %s (%s:%d)" % [Time.get_datetime_string_from_system(), kind,
		rationale if rationale != "" else code, function, file, line]
	for bt in script_backtraces:
		if bt and not bt.is_empty():
			text += "\n" + bt.format(4)
	_mutex.lock()
	count += 1
	_write(text)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass  # plain prints stay in godot.log


func _write(text: String) -> void:
	if _file:
		_file.store_line(text)
		_file.flush()
