extends SceneTree
## Runs every *_test.gd under tests/unit and tests/integration.
## Usage: godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## Exit codes: 0 all passed, 1 failures, 2 no tests found (nothing was checked),
## 3 watchdog expired (a test crashed or stalled, so the run is incomplete).

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]
const WATCHDOG_MSEC := 180000

var _started_msec := 0
var _current_test := "startup"


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	process_frame.connect(_check_watchdog)
	_run.call_deferred()


func _check_watchdog() -> void:
	if Time.get_ticks_msec() - _started_msec > WATCHDOG_MSEC:
		print("NOT ASSESSED: watchdog expired during %s" % _current_test)
		quit(3)


func _run() -> void:
	InputSetup.install()
	var kit := TestKit.new(self)
	var test_count := 0
	for dir_path in TEST_DIRS:
		for file_name in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with("_test.gd"):
				continue
			var path := "%s/%s" % [dir_path, file_name]
			var script: GDScript = load(path)
			if script == null or not script.can_instantiate():
				test_count += 1
				kit.failures.append("%s: script did not load" % path)
				print("FAIL %s: script did not load" % path)
				continue
			var suite: Object = script.new()
			for method in suite.get_method_list():
				var method_name: String = method["name"]
				if not method_name.begins_with("test_"):
					continue
				test_count += 1
				kit.current_test = "%s::%s" % [file_name, method_name]
				_current_test = kit.current_test
				var failures_before := kit.failures.size()
				await suite.call(method_name, kit)
				var passed := kit.failures.size() == failures_before
				print("%s %s" % ["PASS" if passed else "FAIL", kit.current_test])
	for failure in kit.failures:
		print("  FAILURE: %s" % failure)
	print("%d tests, %d checks, %d failures" % [test_count, kit.checks, kit.failures.size()])
	if test_count == 0:
		print("NOT ASSESSED: no tests were found")
		quit(2)
	else:
		quit(1 if kit.failures.size() > 0 else 0)
