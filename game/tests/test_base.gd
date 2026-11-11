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


## Relative tolerance for values above 1, absolute below.
func assert_near(actual: float, expected: float, message: String, tolerance: float = 1e-6) -> void:
	if absf(actual - expected) > tolerance * maxf(1.0, absf(expected)):
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
