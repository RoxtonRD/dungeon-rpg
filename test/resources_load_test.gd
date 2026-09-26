## Every .tres under resources/ and every .gd under scripts/ loads without
## an engine error. Catches broken ext_resource ids, bad paths, and GDScript
## parse errors before they reach the game.
extends GdUnitTestSuite

const TestFiles := preload("res://test/support/test_files.gd")


## Collects every engine error (and script error) logged while it is attached.
## gdUnit4 only fails a test on script errors by default; a broken .tres logs a
## plain engine error, so we listen for those ourselves.
class ErrorCatcher extends Logger:
	var errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if not rationale.is_empty() else code
		errors.append("%s (%s:%d %s)" % [text, file, line, function])


var _catcher: ErrorCatcher


func before_test() -> void:
	_catcher = ErrorCatcher.new()
	OS.add_logger(_catcher)


func after_test() -> void:
	OS.remove_logger(_catcher)
	_catcher = null


func test_all_resources_load() -> void:
	var paths := TestFiles.find("res://resources", ".tres")
	assert_array(paths).is_not_empty()
	assert_array(_load_failures(paths)).is_empty()


func test_all_scripts_load() -> void:
	var paths := TestFiles.find("res://scripts", ".gd")
	assert_array(paths).is_not_empty()
	assert_array(_load_failures(paths)).is_empty()


## Loads each path fresh (bypassing the cache, so files the autoloads already
## loaded are parsed again) and returns one line per file that failed.
func _load_failures(paths: PackedStringArray) -> PackedStringArray:
	var failures: PackedStringArray = []
	for path in paths:
		_catcher.errors.clear()
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			failures.append("%s: did not load" % path)
		elif res is Script and not (res as Script).can_instantiate():
			failures.append("%s: script does not compile" % path)
		for error in _catcher.errors:
			failures.append("%s: %s" % [path, error])
	return failures
