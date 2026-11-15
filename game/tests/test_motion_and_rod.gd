extends "res://tests/test_base.gd"
## Phone motion gestures (owner request 2026-11-14), the spring rod, and
## working the lure in the wait.


func test_fast_flick_back_is_a_strike_once() -> void:
	var g := MotionGesture.new()
	g.calibrate(0.3)
	var calm := g.add_sample(1.0 / 60.0, 0.5, 0.3)
	assert_true(not calm["strike"], "a slow movement is not a strike")
	var flick := g.add_sample(1.0 / 60.0, 6.0, 0.35)
	assert_true(flick["strike"], "a fast flick back strikes")
	var again := g.add_sample(1.0 / 60.0, 6.0, 0.4)
	assert_true(not again["strike"], "one flick, one strike (cooldown)")
	var forward := MotionGesture.new()
	forward.calibrate(0.3)
	assert_true(not forward.add_sample(1.0 / 60.0, -6.0, 0.25)["strike"], "a flick forwards is not a strike")


func test_tilting_back_pulls_the_rod() -> void:
	var g := MotionGesture.new()
	g.calibrate(0.2)
	var rest := g.add_sample(1.0 / 60.0, 0.0, 0.2)
	assert_near(float(rest["pull"]), 0.0, "rest pose: no pull", 0.001)
	var half := g.add_sample(1.0 / 60.0, 0.0, 0.2 + 0.34)
	var full := g.add_sample(1.0 / 60.0, 0.0, 0.2 + 0.7)
	assert_true(float(half["pull"]) > 0.3 and float(half["pull"]) < 0.8, "half tilt, part pull: %.2f" % half["pull"])
	assert_near(float(full["pull"]), 1.0, "full tilt, full pull", 0.001)
	var moving := g.add_sample(1.0 / 60.0, 3.0, 0.2 + 0.1)
	assert_true(float(moving["pull"]) > float(g.add_sample(1.0 / 60.0, 0.0, 0.2 + 0.1)["pull"]), "speed adds to the pull")


func test_small_twitches_jig_the_lure() -> void:
	var g := MotionGesture.new()
	g.calibrate(0.0)
	var r := {}
	for i in 120:
		var rate := 2.5 if i % 10 < 5 else -2.5
		r = g.add_sample(1.0 / 60.0, rate, 0.02 * sin(i * 0.6))
	assert_true(float(r["jig"]) > 0.8, "steady twitching jigs: %.2f" % r["jig"])
	for i in 180:
		r = g.add_sample(1.0 / 60.0, 0.0, 0.0)
	assert_true(float(r["jig"]) < 0.05, "holding still stops the jig: %.2f" % r["jig"])


func test_rod_bends_more_under_more_load_and_settles() -> void:
	var light := RodSpring.new()
	var heavy := RodSpring.new()
	for i in 240:
		light.step(1.0 / 60.0, Vector2(800, 740), -1.2, 520.0, Vector2(0, 0.3))
		heavy.step(1.0 / 60.0, Vector2(800, 740), -1.2, 520.0, Vector2(0, 1.0))
	assert_true(heavy.total_bend() > light.total_bend() * 2.0, "more load, more bend (%.2f vs %.2f rad)" % [heavy.total_bend(), light.total_bend()])
	assert_true(heavy.total_bend() > 0.4 and heavy.total_bend() < 2.0, "a working curve, not a fold: %.2f rad" % heavy.total_bend())
	var tip_y := heavy.tip().y
	heavy.step(1.0 / 60.0, Vector2(800, 740), -1.2, 520.0, Vector2(0, 1.0))
	assert_near(heavy.tip().y, tip_y, "settled under a steady load", 0.5)
	var tip_angle_share: float = absf(heavy.angles[RodSpring.SEGMENTS - 1]) / maxf(absf(heavy.angles[0]), 1e-6)
	assert_true(tip_angle_share > 1.5, "the tip bends more than the butt (fast action)")


func test_rod_springs_back_after_a_kick() -> void:
	var rod := RodSpring.new()
	rod.step(1.0 / 60.0, Vector2(800, 740), -1.2, 520.0, Vector2.ZERO)
	var rest := rod.tip()
	rod.kick(8.0)
	var moved := 0.0
	for i in 20:
		rod.step(1.0 / 60.0, Vector2(800, 740), -1.2, 520.0, Vector2.ZERO)
		moved = maxf(moved, rod.tip().distance_to(rest))
	for i in 300:
		rod.step(1.0 / 60.0, Vector2(800, 740), -1.2, 520.0, Vector2.ZERO)
	assert_true(moved > 10.0, "a kick moves the tip (%.1f px)" % moved)
	assert_true(rod.tip().distance_to(rest) < 1.0, "and the rod returns to rest")


func test_working_the_lure_raises_interest() -> void:
	var db: Dictionary = DataStore.load_all("res://data")["database"]
	var k := DataStore.load_constants()
	var cond := {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(db, "istavrit", "lrf", "karakoy_east", 0.5, cond)
	var still := 0
	var jigged := 0
	for s in 60:
		var a := WaitSim.new(ctx, k, db["species"], 15.0, s + 1)
		var b := WaitSim.new(ctx, k, db["species"], 15.0, s + 1)
		for i in 30 * 20:
			a.advance(1.0 / 30.0, {"jig": 0.0})
			b.advance(1.0 / 30.0, {"jig": 1.0})
		for e: Dictionary in a.events:
			still += 1 if e["event"] in ["nibble", "take"] else 0
		for e: Dictionary in b.events:
			jigged += 1 if e["event"] in ["nibble", "take"] else 0
	assert_true(jigged > still, "jigging brings more nibbles and takes (%d vs %d)" % [jigged, still])


func test_rod_stays_stable_with_long_frames() -> void:
	var rod := RodSpring.new()
	for i in 6:
		rod.step(1.2, Vector2(800, 740), -1.2, 520.0, Vector2(-0.3, 0.1))   # page-load or screenshot hitches
	for i in 10:
		rod.step(1.0 / 30.0, Vector2(800, 740), -1.2, 520.0, Vector2(-0.3, 0.1))
	assert_true(absf(rod.total_bend()) < 0.5, "long frames do not blow the rod up: %.2f rad" % rod.total_bend())
	for a: float in rod.angles:
		assert_true(absf(a) < 0.59, "no joint sits at the clamp")


func test_hand_tremor_is_not_working_the_lure() -> void:
	var g := MotionGesture.new()
	g.calibrate(0.0)
	var r := {}
	for i in 300:
		r = g.add_sample(1.0 / 60.0, 0.4 * sin(i * 1.3), 0.0)
	assert_true(float(r["jig"]) < 0.05, "a steady hand does not jig: %.2f" % r["jig"])


func test_a_phone_held_still_becomes_the_rest_pose() -> void:
	var g := MotionGesture.new()
	g.calibrate(0.0)
	var pull := 0.0
	for i in 60 * 120:   # two minutes at a new, steady angle
		pull = float(g.add_sample(1.0 / 60.0, 0.0, 0.5)["pull"])
	assert_true(pull < 0.2, "after holding still the new pose is the rest pose: %.2f" % pull)
	var first := MotionGesture.new()
	first.calibrate(0.0)
	assert_true(float(first.add_sample(1.0 / 60.0, 0.0, 0.5)["pull"]) > 0.5, "but the same tilt pulls at once at first")
