extends "res://tests/test_base.gd"
## A beach (owner, 2026-11-24): at least one place where the angler stands on
## sand, and a fish is drawn up out of the wash rather than lifted up a wall.


func _beach_fight(seed_value: int) -> FightSim:
	var ctx := FightSetup.build(Db.database(), "levrek", "spin", "patras_beach", 0.5, {"slot": "dawn", "month": 10, "wind_dir": "NE", "wind_ms": 3})
	var f := FightSim.new(ctx, Db.constants(), 0.9, seed_value)
	f.in_landing = true
	f.landing_q = 1.0
	f.weight_kg = f.b_eff * 0.75
	return f


func test_maro_and_patras_have_a_beach() -> void:
	var beaches: Array[String] = []
	for spot: Dictionary in Db.database()["spot"]:
		for pos: Dictionary in spot["positions"]:
			if String(pos.get("stage", "")) == "beach":
				beaches.append(String(pos["id"]))
	assert_true(beaches.has("maro_beach") and beaches.has("patras_beach"), "beach positions: %s" % str(beaches))


func test_a_beach_is_drawn_up_the_sand_not_lifted() -> void:
	var k := Db.constants()
	assert_eq(FightSim.lift_height(k, {"stage": "beach"}), float(k["LIFT_HEIGHT_BEACH_M"]), "metres of sand")
	var f := _beach_fight(1)
	assert_eq(f.weight_share, float(k["BEACH_WEIGHT_SHARE"]), "the wash and the sand carry most of it")
	var s := f.step({"reel": 0.0, "rod": 0.0, "drag_kg": 1.0})
	assert_true(float(s["tension_kg"]) < f.weight_kg * 0.5, "far less than its weight on the line (%.2f of %.2f kg)" % [float(s["tension_kg"]), f.weight_kg])


func test_a_fish_that_would_part_the_line_up_a_wall_comes_up_a_beach() -> void:
	for seed_value in 20:
		var f := _beach_fight(seed_value)
		while not f.is_over() and f.time_s < 60.0:
			f.step({"reel": 1.0, "rod": 0.0, "drag_kg": 1.0})
		assert_eq(f.outcome, FightSim.OUTCOME_LANDED, "75 %% of the line's strength, reeled through its kicks (seed %d)" % seed_value)


func test_the_landing_view_shows_sand_on_a_beach() -> void:
	var v := LandingView.new()
	v.open("levrek", 40.0, 3.0, "beach")
	assert_true(v.beach and v.quay, "a beach: no rail, a low edge")
	v.open("levrek", 40.0, 5.0, "bridge")
	assert_true(not v.beach and not v.quay, "a bridge")
	v.free()
