extends SceneTree
## Headless runner: godot --headless --path game --script res://tests/run_tests.gd
## Runs every res://tests/test_*.gd (except test_base.gd), calls each test_*
## method, prints a summary and exits non-zero on any failure.

const TEST_DIR := "res://tests"


func _init() -> void:
	var total := 0
	var failed := 0
	for file_name in _test_files():
		var script: GDScript = load("%s/%s" % [TEST_DIR, file_name])
		if script == null or not script.can_instantiate():
			# A parse error used to skip the whole file silently.
			total += 1
			failed += 1
			printerr("FAIL  %s: the test file does not load" % file_name)
			continue
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var instance = script.new()
			instance.call(method_name)
			total += 1
			if instance.failures.is_empty():
				print("PASS  %s::%s" % [file_name, method_name])
			else:
				failed += 1
				for message in instance.failures:
					printerr("FAIL  %s::%s: %s" % [file_name, method_name, message])
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)


func _test_files() -> Array[String]:
	var files: Array[String] = []
	for file_name in DirAccess.get_files_at(TEST_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_base.gd":
			files.append(file_name)
	files.sort()
	return files
