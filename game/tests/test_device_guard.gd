extends "res://tests/test_base.gd"

const DeviceGuardScript := preload("res://ui/device_guard.gd")


func test_portrait_detection() -> void:
	assert_true(DeviceGuardScript.is_portrait(Vector2(720, 1280)), "tall window is portrait")
	assert_true(not DeviceGuardScript.is_portrait(Vector2(1280, 720)), "wide window is landscape")
	assert_true(not DeviceGuardScript.is_portrait(Vector2(800, 800)), "square counts as landscape")
