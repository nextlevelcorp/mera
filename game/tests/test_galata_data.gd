extends "res://tests/test_base.gd"
## The first real spot (owner choice 2026-11-13): the Galata Bridge data loads,
## carries its sources, and plays like the PRD asks.

var _db: Dictionary
var _k: Dictionary


func _init() -> void:
	var loaded := DataStore.load_all("res://data")
	_db = loaded["database"]
	_k = DataStore.load_constants()


func test_game_data_is_valid() -> void:
	var loaded := DataStore.load_all("res://data")
	assert_true(loaded["ok"], "res://data validates: %s" % str(loaded["errors"]))
	assert_eq(_db["spot"].size(), 1, "one spot in the slice")
	assert_eq(_db["spot"][0]["id"], "galata_bridge", "the Galata Bridge")


func test_sourced_fields_carry_their_sources() -> void:
	var spot: Dictionary = _db["spot"][0]
	for field: String in ["lat", "lon", "water_temp_by_month_c", "pressure"]:
		var entry: Dictionary = spot["provenance"]["fields"].get(field, {})
		assert_true(String(entry.get("source", "")) != "", "spot %s has a source" % field)
	for sp: Dictionary in _db["species"]:
		var fields: Dictionary = sp["provenance"]["fields"]
		for field: String in ["scientific_name", "length_min_cm", "length_max_cm", "lw_a", "lw_b", "regulation"]:
			assert_true(String(fields.get(field, {}).get("source", "")) != "", "%s %s has a source" % [sp["id"], field])
		assert_true(sp.has("regulation") and sp["regulation"].has("min_length_cm"), "%s has a legal minimum size" % sp["id"])


func test_every_name_key_is_translated() -> void:
	var csv := FileAccess.get_file_as_string("res://locale/translations.csv")
	var keys := [_db["spot"][0]["name_key"]]
	for p: Dictionary in _db["spot"][0]["positions"]:
		keys.append(p["name_key"])
	for entity: String in ["species", "rod", "reel", "line", "leader", "lure", "angler"]:
		for r: Dictionary in _db[entity]:
			keys.append(r["name_key"])
	for key: String in keys:
		assert_true(csv.contains("\n%s," % key), "%s is in translations.csv" % key)
		assert_true(not key.begins_with("DEMO_"), "%s is not a demo key" % key)


func test_october_evening_wait_is_in_the_prd_band() -> void:
	var cond := {"slot": "evening", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(_db, "istavrit", "lrf", "karakoy_east", 0.5, cond)
	var w := WaitSim.new(ctx, _k, _db["species"], 15.0, 1)
	var m := w.median_wait_s()
	assert_true(m >= 20.0 and m <= 40.0, "best case at Galata: median wait %.0f s within 20-40 s (PRD F6)" % m)


func test_bonito_is_absent_in_its_closed_season() -> void:
	var cond := {"slot": "dawn", "month": 6, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(_db, "palamut", "spin", "karakoy_east", 0.5, cond)
	var w := WaitSim.new(ctx, _k, _db["species"], 15.0, 1)
	assert_eq(float(w._rates["palamut"]["rate_interest"]), 0.0, "no bonito in June (closed 1 April - 14 August; Zengin 2009: September to November)")


func test_every_species_can_be_fought_on_both_rigs() -> void:
	var cond := {"slot": "evening", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	for sp: Dictionary in _db["species"]:
		for tackle: String in FightSetup.TACKLES:
			var ctx := FightSetup.build(_db, sp["id"], tackle, "karakoy_east", 0.7, cond)
			var c := FightController.new(ctx, _k, 3)
			var guard := 0
			while c.hud()["outcome"] == "" and guard < 20000:
				c.advance(1.0 / 30.0, {"reel": 1.0, "rod": 0.0, "drag_kg": float(ctx["reel"]["drag_max_kg"]) / 3.0})
				guard += 1
			assert_true(c.hud()["outcome"] != "", "%s on %s ends: %s" % [sp["id"], tackle, c.hud()["outcome"]])
