extends "res://tests/test_base.gd"
## The cast swing, line pay-out, thumb aim, motion sensor helpers and the
## angler rig (owner feedback 2026-11-15).


func test_windup_grows_with_power() -> void:
	var weak := CastMotion.new()
	var strong := CastMotion.new()
	for i in 60:
		weak.charge(1.0 / 60.0, 0.3)
		strong.charge(1.0 / 60.0, 1.0)
	assert_true(strong.angle > weak.angle * 2.0, "more power, rod further back (%.2f vs %.2f rad)" % [strong.angle, weak.angle])
	assert_true(strong.angle > 1.0 and strong.angle < 1.5, "full wind-up over the shoulder: %.2f rad" % strong.angle)


func test_release_snaps_forward_then_settles() -> void:
	var c := CastMotion.new()
	for i in 60:
		c.charge(1.0 / 60.0, 1.0)
	c.release(1.0)
	var most_forward := 0.0
	for i in 90:   # 1.5 s
		c.settle(1.0 / 60.0)
		most_forward = minf(most_forward, c.angle)
	assert_true(most_forward < -0.1, "the snap overshoots forward: %.2f rad" % most_forward)
	assert_true(absf(c.angle) < 0.03, "and settles within 1.5 s: %.3f rad" % c.angle)


func test_line_pays_out_to_the_cast_distance() -> void:
	var last := -1.0
	for i in 31:
		var paid := CastMotion.paid_out(i * 0.05, 1.5, 24.0)
		assert_true(paid >= last, "pay-out never runs backwards")
		last = paid
	assert_near(CastMotion.paid_out(1.5, 1.5, 24.0), 24.0, "all line out at landing", 0.001)
	assert_true(CastMotion.paid_out(0.375, 1.5, 24.0) > 24.0 * 0.4, "fast at first (ease-out)")


func test_thumb_aim_is_clamped_and_symmetric() -> void:
	assert_near(CastMotion.aim_from_drag(0.0, 1280.0), 0.0, "no swipe, straight", 1e-6)
	assert_near(CastMotion.aim_from_drag(1000.0, 1280.0), CastMotion.AIM_MAX, "clamped right", 1e-6)
	assert_near(CastMotion.aim_from_drag(-1000.0, 1280.0), -CastMotion.AIM_MAX, "clamped left", 1e-6)
	assert_near(CastMotion.aim_from_drag(96.0, 1280.0), -CastMotion.aim_from_drag(-96.0, 1280.0), "symmetric", 1e-6)


func test_same_aim_and_seed_land_in_the_same_place() -> void:
	var a = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	var b = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	assert_true(a.has_method("setup"), "the fishing screen script loads")
	a.setup("")
	b.setup("")
	a.cast_with_power(0.8, 0.15)
	b.cast_with_power(0.8, 0.15)
	assert_eq(a._aim_x, b._aim_x, "same seed and input, same aim (PRD F5)")
	assert_eq(a._cast["cast_m"], b._cast["cast_m"], "and the same distance")
	var c = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	c.setup("")
	c.cast_with_power(0.8, -0.15)
	assert_true(c._aim_x < a._aim_x, "aiming left lands further left")
	a.free()
	b.free()
	c.free()


func test_bail_opens_for_the_cast_and_closes_on_landing() -> void:
	var s = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	s.setup("")
	s._overlay.size = Vector2(1280, 720)
	s._process(1.0 / 30.0)
	assert_true(not s._rig.bail_open, "bail closed while ready")
	s.cast_with_power(0.6)
	s._process(1.0 / 30.0)
	assert_true(s._rig.bail_open, "bail open in flight")
	var guard := 0
	while s.phase == s.Phase.FLIGHT and guard < 600:
		s._process(1.0 / 30.0)
		guard += 1
	s._process(1.0 / 30.0)
	assert_true(not s._rig.bail_open, "bail closed once the lure lands")
	s.free()


func test_motion_helpers() -> void:
	assert_true(DeviceMotion.pitch_from_gravity(4.9, false) > 0.4, "screen turned up reads as tipped back")
	assert_true(DeviceMotion.pitch_from_gravity(4.9, true) < -0.4, "inverted sign (iPhone) flips it")
	assert_true(DeviceMotion.signed_rate(3.0, 0.01) > 0.0 and DeviceMotion.signed_rate(-3.0, 0.01) > 0.0, "direction comes from the pitch change, not the gyro sign")
	assert_true(DeviceMotion.signed_rate(3.0, -0.01) < 0.0, "tipping forward is negative")


func test_reel_handle_has_inertia_and_spool_turns_back_when_line_goes_out() -> void:
	var rig := AnglerRig.new()
	rig.update(1.0 / 60.0, 14.0, 0.0)
	assert_true(rig.crank_speed < 14.0 * 0.3, "the handle does not jump to full speed")
	for i in 60:
		rig.update(1.0 / 60.0, 14.0, 0.0)
	assert_near(rig.crank_speed, 14.0, "it reaches the target speed", 0.2)
	var before := rig.spool
	for i in 30:
		rig.update(1.0 / 60.0, 0.0, 1.5)
	assert_true(rig.spool < before, "line going out turns the spool backwards")
