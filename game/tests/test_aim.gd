extends "res://tests/test_base.gd"
## Roadmap R19: casting left and right.


func _screen() -> FishingScreen:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "lrf", {"slot": "day", "month": 10, "wind_dir": "N", "wind_ms": 0})
	scr.setup("")
	return scr


func test_the_left_thumb_on_the_gauge_maps_to_an_aim_angle() -> void:
	assert_eq(CastMotion.aim_from_gauge(CastMotion.GAUGE_CENTRE_X), 0.0, "the gauge's centre is straight out")
	assert_eq(CastMotion.aim_from_gauge(CastMotion.GAUGE_CENTRE_X - CastMotion.GAUGE_HALF_W), -CastMotion.AIM_MAX, "its left end is full left")
	assert_eq(CastMotion.aim_from_gauge(CastMotion.GAUGE_CENTRE_X + CastMotion.GAUGE_HALF_W), CastMotion.AIM_MAX, "its right end is full right")
	assert_eq(CastMotion.aim_from_gauge(-500.0), -CastMotion.AIM_MAX, "clamped")
	assert_true(CastMotion.GAUGE_CENTRE_X + CastMotion.GAUGE_HALF_W < 1280.0 * 0.45, "the whole gauge is in the left part of the screen")


func test_the_left_thumb_aims_before_the_cast_too() -> void:
	var scr := _screen()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(CastMotion.GAUGE_CENTRE_X + 100.0, 650.0)
	scr._gui_input(touch)
	assert_true(scr._aim > 0.3, "ready: a touch right of the gauge's centre aims right (%.2f)" % scr._aim)
	touch.position = Vector2(900.0, 400.0)
	var before := scr._aim
	scr._gui_input(touch)
	assert_eq(scr._aim, before, "a touch on the right half does not aim")
	scr.free()
	assert_true(CastMotion.AIM_MAX >= 0.45, "wide enough to see on screen")


func test_the_other_thumb_aims_while_cast_is_held_and_the_aim_stays() -> void:
	var scr := _screen()
	scr.begin_charge()
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(100.0, 300.0)
	scr._gui_input(touch)
	assert_true(scr._aim < -0.3, "a tap on the left aims left (%.2f)" % scr._aim)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(CastMotion.GAUGE_CENTRE_X + 120.0, 300.0)
	scr._gui_input(drag)
	assert_true(scr._aim > 0.3, "dragging to the right aims right")
	var aimed := scr._aim
	scr.release_cast()
	assert_true(scr._aim_x > 0.1, "the cast goes right (%.2f)" % scr._aim_x)
	scr._set_phase(FishingScreen.Phase.READY)
	scr.begin_charge()
	assert_eq(scr._aim, aimed, "the next cast keeps the aim")
	scr.free()


func test_water_touches_reach_the_screen_not_the_title_behind_it() -> void:
	var scr := _screen()
	assert_eq(scr.mouse_filter, Control.MOUSE_FILTER_STOP, "the fishing view takes the touches no button took")
	for c: Control in [scr._ui, scr._overlay, scr._water]:
		assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets them through" % c.get_class())
	scr.free()


func test_the_rod_goes_back_once_and_stays_while_cast_is_held() -> void:
	var prev := 0.0
	for i in 301:   # three seconds: two full power swings
		var t := float(i) / 100.0
		var w := FishingScreen.windup_target(t)
		assert_true(w >= prev, "never forward again while held (t %.2f)" % t)
		prev = w
	assert_eq(FishingScreen.windup_target(3.0), 1.0, "fully back and held")
	assert_true(FishingScreen.power_at(1.05) < 0.6, "while the power itself swings back down")


func test_gulls_roost_at_night() -> void:
	assert_true(GullFlock.flies_at("day") and GullFlock.flies_at("dawn") and GullFlock.flies_at("evening"), "gulls fly by day")
	assert_true(not GullFlock.flies_at("night"), "but not at night")


func test_the_anglers_stand_differently_every_session() -> void:
	var a := NeighborAnglers.layout(1, 4, 3.0, 14.0)
	var b := NeighborAnglers.layout(1, 4, 3.0, 14.0)
	var c := NeighborAnglers.layout(2, 4, 3.0, 14.0)
	assert_eq(a, b, "the same seed, the same layout")
	assert_true(a != c, "another session, another layout")
	for i in range(1, 4):
		assert_true(float(a[i]["x"]) - float(a[i - 1]["x"]) >= NeighborAnglers.MIN_GAP_M - 0.001, "never too close")
	var states := {}
	for seed_value in 30:
		for p: Dictionary in NeighborAnglers.new(seed_value).people:
			states[int(p["state"])] = true
	assert_true(states.has(NeighborAnglers.S.IDLE) and states.has(NeighborAnglers.S.BAIT) and states.has(NeighborAnglers.S.REST) and states.has(NeighborAnglers.S.FIGHT),
		"sessions start them waiting, baiting, resting or into a fish: %s" % str(states.keys()))
