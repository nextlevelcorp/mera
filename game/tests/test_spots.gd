extends "res://tests/test_base.gd"
## Roadmap R14: more than one spot (Sarayburnu), fished by the same screens.


func test_positions_are_unique_across_spots_and_find_their_spot() -> void:
	var db := Db.database()
	var seen := {}
	for s: Dictionary in db["spot"]:
		for p: Dictionary in s["positions"]:
			assert_true(not seen.has(p["id"]), "%s is unique" % p["id"])
			seen[p["id"]] = s["id"]
			assert_eq(FightSetup.spot_of(db, p["id"])["id"], s["id"], "%s belongs to %s" % [p["id"], s["id"]])
	assert_eq(FightSetup.spot_of(db, "no_such_position")["id"], "galata_bridge", "an unknown position falls back to the first spot")


func test_the_second_spot_is_labelled_and_uses_known_species_and_stages() -> void:
	var db := Db.database()
	var spot: Dictionary = db["spot"][1]
	assert_eq(spot["id"], "sarayburnu", "Sarayburnu")
	for field: String in ["lat", "lon", "water_temp_by_month_c", "species"]:
		assert_true(String(spot["provenance"]["fields"].get(field, {}).get("source", "")) != "", "%s has a source" % field)
	for p: Dictionary in spot["positions"]:
		assert_true(p["provenance"]["default"].get("design_fill", false) == true, "%s is labelled a design fill" % p["id"])
		assert_true(String(p["stage"]) in Stage3D.KINDS, "%s has a known stage" % p["id"])
		assert_true(TranslationServer.translate(p["name_key"]) != p["name_key"], "%s is translated" % p["id"])
	assert_true(TranslationServer.translate(spot["name_key"]) != spot["name_key"], "the spot is translated")


func test_the_fishing_screen_follows_the_requested_spot() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("sarayburnu", "sarayburnu_marmara", "", {"slot": "dawn", "month": 10, "wind_dir": "S", "wind_ms": 4})
	scr.setup("")
	assert_eq(scr.spot()["id"], "sarayburnu", "the requested spot")
	assert_eq(scr.position_id, "sarayburnu_marmara", "and position")
	assert_eq(scr._ctx["position"]["facing"], "S", "the model reads that position")
	assert_eq(scr._ctx["spot"]["id"], "sarayburnu", "and that spot")
	# A position that is not at the requested spot is ignored for the spot's first.
	var other := FishingScreen.new()
	other.request = Game.fishing_request("sarayburnu", "karakoy_east", "", {"slot": "dawn", "month": 10, "wind_dir": "S", "wind_ms": 4})
	other.setup("")
	assert_eq(other.position_id, "sarayburnu_tip", "a position of another spot gives the spot's first")
	# Cycling positions stays at the spot.
	var first := scr.position_id
	scr.set_rig(scr.rig, "sarayburnu_horn")
	assert_eq(scr.spot()["id"], "sarayburnu", "still at Sarayburnu")
	assert_true(first != scr.position_id, "the position changed")
	scr.free()
	other.free()


func test_bites_come_at_the_second_spot_in_season() -> void:
	var db := Db.database()
	var k := Db.constants()
	var cond := {"slot": "dawn", "month": 10, "wind_dir": "S", "wind_ms": 3}
	var ctx := FightSetup.build(db, "lufer", "spin", "sarayburnu_marmara", 0.5, cond)
	var wait := WaitSim.new(ctx, k, db["species"], 20.0, 5).median_wait_s()
	assert_true(wait > 3.0 and wait < 600.0, "median wait at Sarayburnu in October: %.0f s" % wait)
	var summer := FightSetup.build(db, "palamut", "spin", "sarayburnu_marmara", 0.5, {"slot": "dawn", "month": 2, "wind_dir": "S", "wind_ms": 3})
	var p := CatchModel.presence(k, summer["species"], summer["spot"], summer["position"], {"slot": "dawn", "month": 2, "wind_dir": "S", "wind_ms": 3}, CatchModel.environment(k, summer["spot"], summer["position"], {"slot": "dawn", "month": 2, "wind_dir": "S", "wind_ms": 3}), 10.0)
	assert_eq(float(p["presence"]), 0.0, "no bonito in February")
