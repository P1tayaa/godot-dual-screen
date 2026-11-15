class_name ErrorCollector
extends Logger
## Collects engine and script errors while a test runs, so a test that crashes midway fails instead of passing.

var errors: PackedStringArray = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == Logger.ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
	_mutex.unlock()


func take() -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = errors
	errors = []
	_mutex.unlock()
	return out
