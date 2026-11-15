class_name TestRunner
extends SceneTree
## Headless test runner (no addon):
##   $GODOT_PATH --headless --path . --script res://addons/dual_screen/testing/run_tests.gd [-- --only=<file name part>] [--verbose]
## Runs every `test_*` method of every tests/test_*.gd file. A test also fails if any engine or script error is logged
## while it runs. Exit code 0 = all passed.

## A test still waiting after this long fails (and the runner moves on).
const TIMEOUT_MS := 15000

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var only: String = ""
	var verbose: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a == "--verbose":
			verbose = true
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var passed: int = 0
	var failed: int = 0
	var files: PackedStringArray = DirAccess.get_files_at("res://tests")
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd") or file == "test_case.gd":
			continue
		if only != "" and not file.contains(only):
			continue
		var script: GDScript = load("res://tests/" + file)
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			if verbose:
				print("[run]  %s.%s" % [file.get_basename(), name])
			var t: TestCase = script.new()
			t.tree = self
			t.before_each()
			var state: Dictionary = {"done": false}
			var body := func() -> void:
				await t.call(name)
				state["done"] = true
			body.call()
			var started: int = Time.get_ticks_msec()
			while not state["done"] and Time.get_ticks_msec() - started < TIMEOUT_MS:
				await process_frame
			if not state["done"]:
				t.failures.append("timed out after %d s" % (TIMEOUT_MS / 1000))
			t.after_each()
			t.cleanup()
			await process_frame
			for e: String in collector.take():
				t.failures.append("error: " + e)
			if t.failures.is_empty():
				passed += 1
				print("[ok]   %s.%s" % [file.get_basename(), name])
			else:
				failed += 1
				print("[FAIL] %s.%s" % [file.get_basename(), name])
				for f: String in t.failures:
					print("         " + f)
	OS.remove_logger(collector)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
