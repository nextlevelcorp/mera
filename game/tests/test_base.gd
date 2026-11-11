extends RefCounted
## Minimal headless test base. Subclasses define test_* methods and call the
## assert helpers; the runner collects failures. (No test plugin yet: adding
## GUT needs the owner's approval.)

var failures: Array[String] = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
