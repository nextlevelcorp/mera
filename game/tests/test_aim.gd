extends "res://tests/test_base.gd"
## Roadmap R19: casting left and right.


func _screen() -> FishingScreen:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "lrf", {"slot": "day", "month": 10, "wind_dir": "N", "wind_ms": 0})
	scr.setup("")
	return scr


func test_a_tap_on_the_water_maps_to_an_aim_angle() -> void:
	assert_eq(CastMotion.aim_from_screen(640.0, 1280.0), 0.0, "the middle is straight out")
	assert_eq(CastMotion.aim_from_screen(0.0, 1280.0), -CastMotion.AIM_MAX, "the left edge is full left")
	assert_eq(CastMotion.aim_from_screen(1280.0, 1280.0), CastMotion.AIM_MAX, "the right edge is full right")
	assert_eq(CastMotion.aim_from_screen(-500.0, 1280.0), -CastMotion.AIM_MAX, "clamped")
	assert_true(CastMotion.AIM_MAX >= 0.45, "wide enough to see on screen")


func test_the_other_thumb_aims_while_cast_is_held_and_the_aim_stays() -> void:
	var scr := _screen()
	scr.begin_charge()
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(100.0, 300.0)
	scr._unhandled_input(touch)
	assert_true(scr._aim < -0.3, "a tap on the left aims left (%.2f)" % scr._aim)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(1180.0, 300.0)
	scr._unhandled_input(drag)
	assert_true(scr._aim > 0.3, "dragging to the right aims right")
	var aimed := scr._aim
	scr.release_cast()
	assert_true(scr._aim_x > 0.1, "the cast goes right (%.2f)" % scr._aim_x)
	scr._set_phase(FishingScreen.Phase.READY)
	scr.begin_charge()
	assert_eq(scr._aim, aimed, "the next cast keeps the aim")
	scr.free()
