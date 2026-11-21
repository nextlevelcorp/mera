extends "res://tests/test_base.gd"
## The landing (owner's play notes, 2026-11-21): the fish is lifted straight
## up the wall on the line, and a kick reeled through can part a light line.


func _cond() -> Dictionary:
	return {"slot": "dawn", "month": 10, "wind_dir": "NE", "wind_ms": 3}


func _hanging(weight_share: float, seed_value: int, position: int = 0) -> FightSim:
	var spot: Dictionary = Db.database()["spot"][0]
	var ctx := FightSetup.build(Db.database(), "istavrit", "lrf", spot["positions"][position]["id"], 0.5, _cond())
	var f := FightSim.new(ctx, Db.constants(), 0.9, seed_value)
	f.in_landing = true
	f.landing_q = 1.0   # no shaking off: only the line is tested here
	f.weight_kg = f.b_eff * weight_share
	return f


## Reels at full speed, or only while the fish is still (between kicks).
func _lift(f: FightSim, between_kicks: bool) -> String:
	while not f.is_over() and f.time_s < 60.0:
		f.step({"reel": 0.0 if between_kicks and f.kicking else 1.0, "rod": 0.0, "drag_kg": 1.0})
	return f.outcome


func test_a_heavy_fish_reeled_through_its_kicks_parts_the_line() -> void:
	var broke := 0
	for seed_value in 30:
		if _lift(_hanging(0.75, seed_value), false) == FightSim.OUTCOME_LINE_BREAK:
			broke += 1
	assert_true(broke >= 20, "reeling through a kick with 75 %% of the line's strength hanging parts it (%d of 30)" % broke)


func test_lifting_between_kicks_brings_the_same_fish_up() -> void:
	for seed_value in 30:
		assert_eq(_lift(_hanging(0.75, seed_value), true), FightSim.OUTCOME_LANDED, "waiting out the kicks lands it (seed %d)" % seed_value)


func test_a_small_fish_never_parts_the_line() -> void:
	for seed_value in 30:
		assert_eq(_lift(_hanging(0.1, seed_value), false), FightSim.OUTCOME_LANDED, "a light fish comes straight up")


func test_the_whole_weight_and_the_kick_are_on_the_line() -> void:
	var f := _hanging(0.3, 1)
	var seen := {}
	while not f.is_over():
		var s := f.step({"reel": 1.0, "rod": 0.0, "drag_kg": 1.0})
		seen[snappedf(float(s["tension_kg"]) / f.weight_kg, 0.01)] = true
	assert_true(seen.has(1.0) and seen.has(snappedf(1.0 + float(Db.constants()["LAND_KICK_SURGE"]), 0.01)), "still: its weight; kicking: more (%s)" % str(seen.keys()))


func test_a_bridge_is_a_longer_lift_than_a_quay() -> void:
	var k := Db.constants()
	assert_eq(FightSim.lift_height(k, {"stage": "bridge"}), float(k["LIFT_HEIGHT_BRIDGE_M"]), "bridge")
	assert_eq(FightSim.lift_height(k, {"stage": "quay"}), float(k["LIFT_HEIGHT_QUAY_M"]), "quay")
	var f := _hanging(0.05, 2)
	_lift(f, false)
	var expected := float(k["LIFT_HEIGHT_BRIDGE_M"]) / float(k["LAND_LIFT_M_PER_S"])
	assert_true(absf(f.landing_s - expected) < 0.2, "a full-speed lift up the bridge takes height / speed (%.1f s, expected %.1f s)" % [f.landing_s, expected])


func test_the_undersize_fish_of_a_landing_go_back_in_the_sea() -> void:
	var spot: Dictionary = Db.database()["spot"][0]
	var s := FishingSession.new(Db.database(), Db.constants(), "capari", spot["positions"][0]["id"], _cond())
	var trip: Array = s.trip["catches"]
	trip.append({"species_id": "istavrit", "length_cm": 16.0, "weight_kg": 0.04, "kept": true})   # an earlier, legal fish
	trip.append({"species_id": "istavrit", "length_cm": 10.0, "weight_kg": 0.01, "kept": true})
	trip.append({"species_id": "istavrit", "length_cm": 13.0, "weight_kg": 0.02, "kept": true})
	trip.append({"species_id": "istavrit", "length_cm": 9.0, "weight_kg": 0.01, "kept": true})
	assert_eq(s.undersize_count(3), 2, "two of this landing's three are under 12 cm")
	assert_eq(s.release_undersize(3), 2, "both go back")
	var kept: Array = []
	for c: Dictionary in trip:
		if c["kept"]:
			kept.append(c["length_cm"])
	assert_eq(kept, [16.0, 13.0], "the legal ones stay in the bucket")
	var result := Game.empty_result()
	result["catches"] = trip
	var save := SaveGame.fresh()
	SaveGame.apply_result(save, result, "2026-11-21")
	var fish := 0
	for item: Dictionary in Inventory.items(save):
		if String(item["id"]).begins_with(Inventory.FISH_PREFIX):
			fish += 1
	assert_eq(fish, 2, "only the kept fish reach the bag")
