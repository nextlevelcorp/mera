extends "res://tests/test_base.gd"
## Bait shoals: where the cast lands matters.


func _k() -> Dictionary:
	return DataStore.load_constants()


func test_same_seed_same_shoals() -> void:
	var a := ShoalField.new(_k(), 5)
	var b := ShoalField.new(_k(), 5)
	for i in 600:
		a.advance(0.1)
		b.advance(0.1)
	assert_eq(a.shoals, b.shoals, "deterministic")
	var c := ShoalField.new(_k(), 6)
	assert_true(c.shoals[0]["pos"] != ShoalField.new(_k(), 5).shoals[0]["pos"], "another seed, other shoals")


func test_boost_is_strongest_in_the_shoal_and_fades() -> void:
	var f := ShoalField.new(_k(), 5)
	var s: Dictionary = f.shoals[0]
	s["age_s"] = 60.0
	s["left_s"] = 60.0
	var p: Vector2 = s["pos"]
	var mid := f.boost_at(p.x, p.y)
	assert_near(mid, 1.0 + float(_k()["SHOAL_FIELD_GAIN"]), "full gain in the middle", 0.001)
	assert_true(f.boost_at(p.x + float(s["radius"]), p.y) < mid, "weaker at the edge")
	assert_true(f.boost_at(p.x + 200.0, p.y) < 1.01, "nothing far away")
	s["left_s"] = 0.5
	assert_true(f.boost_at(p.x, p.y) < mid, "a shoal that breaks up feeds less")


func test_shoals_stay_in_front_and_come_back() -> void:
	var f := ShoalField.new(_k(), 9)
	for i in 6000:
		f.advance(0.1)
		for s: Dictionary in f.shoals:
			var p: Vector2 = s["pos"]
			assert_true(p.y >= 7.9 and p.y <= 55.1, "inside casting water")
	assert_eq(f.shoals.size(), int(_k()["SHOAL_FIELD_COUNT"]), "always the same number of shoals")


func test_a_lure_in_the_shoal_gets_more_interest() -> void:
	var db: Dictionary = DataStore.load_all("res://data")["database"]
	var k := _k()
	var pos_id: String = db["spot"][0]["positions"][0]["id"]
	var ctx := FightSetup.build(db, db["spot"][0]["species"][0]["species_id"], "lrf", pos_id, 0.5, {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 3})
	var inside := 0
	var outside := 0
	for seed_value in range(1, 31):
		for near in [true, false]:
			var w := WaitSim.new(ctx, k, db["species"], 20.0, seed_value)
			var f := ShoalField.new(k, 4)
			f.shoals[0]["pos"] = Vector2(0.0, 20.0) if near else Vector2(300.0, 20.0)
			f.shoals[0]["vel"] = Vector2.ZERO
			f.shoals[0]["age_s"] = 60.0
			f.shoals[0]["left_s"] = 1e6
			f.shoals[1]["pos"] = Vector2(300.0, 40.0)
			f.shoals[1]["vel"] = Vector2.ZERO
			f.shoals[1]["left_s"] = 1e6
			w.shoals = f
			for i in 300:
				w.advance(1.0 / 30.0, {"reel": 0.0})
			var n := 0
			for e: Dictionary in w.events:
				if e["event"] in ["nibble", "take"]:
					n += 1
			if near:
				inside += n
			else:
				outside += n
	assert_true(inside > outside * 1.5, "more fish come to a lure in the shoal (%d against %d)" % [inside, outside])


func test_gulls_follow_their_shoal() -> void:
	var f := ShoalField.new(_k(), 5)
	for s: Dictionary in f.shoals:
		s["age_s"] = 60.0
		s["left_s"] = 1e6
		s["vel"] = Vector2.ZERO
	var g := GullFlock.new(f.shoals.size())
	for i in 1500:
		g.update(1.0 / 30.0, f)
	for gull: Dictionary in g.gulls:
		var pos: Vector3 = gull["pos"]
		var centre: Vector2 = f.shoals[int(gull["shoal"])]["pos"]
		assert_true(Vector2(pos.x, pos.z).distance_to(centre) < 20.0, "a gull circles its shoal")
		assert_true(pos.y >= 0.0, "and stays above the water")


func test_bridge_builds_and_keeps_the_rail_left_of_the_casting_water() -> void:
	var b := Bridge3D.new()
	var n := NeighborAnglers.new(5)
	b.pose(n.people, 1.0)
	for i in n.people.size():
		var tip := b.tip_water(i)
		assert_true(tip.y > 2.0 and tip.y < 6.0, "rod tip %d is above the rail (%.2f m)" % [i, tip.y])
		assert_true(tip.x > Bridge3D.rail_x_at(tip.z), "and out over the water")
		var lure := b.lure_water(i, 10.0, 0.0)
		assert_true(lure.x > Bridge3D.rail_x_at(lure.y) + 3.0, "its lure is in the water")
	# The widest left aim still lands in the water, and so does every shoal.
	for d in [3.0, 10.0, 25.0, 50.0]:
		var z: float = 4.6 + d
		assert_true(-0.3 - tan(0.5) * d > Bridge3D.rail_x_at(z) + 0.5, "a cast %d m out to the left is right of the rail" % int(d))
	var f := ShoalField.new(_k(), 3)
	for i in 3000:
		f.advance(0.2)
		for s: Dictionary in f.shoals:
			var p: Vector2 = s["pos"]
			assert_true(p.x > Bridge3D.rail_x_at(p.y), "a shoal stays in the water")
	b.free()
