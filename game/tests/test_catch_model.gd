extends "res://tests/test_base.gd"
## Staged catch resolution against the worked examples of docs/data_model.md
## section 6. Expected numbers come from an independent Python reference that
## also fed docs/data_model_examples.xlsx. All values are design fills.

const CatchModelScript := preload("res://sim/catch_model.gd")
const FIXTURE_DIR := "res://tests/fixtures"

var _db: Dictionary
var _k: Dictionary


func _setup() -> void:
	_db = DataStore.load_all(FIXTURE_DIR)["database"]
	var errors: Array[String] = []
	_k = DataStore.load_constants(errors)


func _by_id(entity: String, id: String) -> Dictionary:
	for record: Dictionary in _db[entity]:
		if record["id"] == id:
			return record
	return {}


func _ctx(example: Dictionary) -> Dictionary:
	var t: String = example["tackle"]
	var spot: Dictionary = _db["spot"][0]
	var position: Dictionary = {}
	for p: Dictionary in spot["positions"]:
		if p["id"] == example["position"]:
			position = p
	return {
		"species": _by_id("species", example["species"]), "spot": spot, "position": position,
		"rod": _by_id("rod", "%s_rod" % t), "reel": _by_id("reel", "%s_reel" % t), "line": _by_id("line", "%s_line" % t),
		"leader": _by_id("leader", "%s_leader" % t), "lure": _by_id("lure", "lrf_soft" if t == "lrf" else "spin_minnow"),
		"angler": _by_id("angler", "default"), "conditions": example["conditions"], "play": example["play"],
	}


func _examples() -> Array:
	var errors: Array[String] = []
	return DataStore.read_json("%s/examples.json" % FIXTURE_DIR, errors)


func test_helpers() -> void:
	_setup()
	assert_near(CatchModelScript.n(1), 0.0, "n(1)")
	assert_near(CatchModelScript.n(20), 1.0, "n(20)")
	assert_near(CatchModelScript.band(5, 2, 8, 3), 1.0, "inside band")
	assert_near(CatchModelScript.band(9, 2, 8, 2), 0.5, "half way out of the band")
	assert_near(CatchModelScript.band(20, 2, 8, 3), 0.0, "far outside the band")
	var profile: Array = (_by_id("spot", "fixture_pier")["positions"][0]["depth_profile"])
	assert_near(CatchModelScript.depth_at(profile, 0), 2.0, "depth at the shore")
	assert_near(CatchModelScript.depth_at(profile, 5), 5.0, "depth interpolated")
	assert_near(CatchModelScript.depth_at(profile, 20), 8.0, "depth on the plateau")
	assert_near(CatchModelScript.depth_at(profile, 500), 8.0, "depth beyond the last point")


func test_worked_examples_match_the_reference() -> void:
	_setup()
	var species_list: Array = _db["species"]
	for example: Dictionary in _examples():
		var ctx := _ctx(example)
		var r := CatchModelScript.resolve(ctx, _k)
		var e: Dictionary = example["expected"]
		var name: String = example["name"]
		assert_near(r["environment"]["chop"], e["chop"], "%s chop" % name)
		assert_near(r["environment"]["clarity_eff"], e["clarity_eff"], "%s clarity" % name)
		assert_near(r["environment"]["visibility"], e["visibility"], "%s visibility" % name)
		assert_near(r["presence"]["presence"], e["presence"], "%s presence" % name)
		assert_near(r["presence"]["D"], e["D"], "%s D" % name)
		assert_near(r["presence"]["S"], e["S"], "%s S" % name)
		for key in ["G", "M", "Z", "V", "F"]:
			assert_near(r["attraction"][key], e[key], "%s %s" % [name, key])
		assert_near(r["attraction"]["attraction"], e["attraction"], "%s attraction" % name)
		assert_near(r["commit"]["commit"], e["commit"], "%s commit" % name)
		assert_near(r["commit"]["rate_take"], e["rate_take"], "%s take rate" % name)
		assert_near(r["commit"]["strike_window_s"], e["strike_window_s"], "%s strike window" % name)
		for key in ["H1", "H2", "H3"]:
			assert_near(r["hook"][key], e[key], "%s %s" % [name, key])
		assert_near(r["hook"]["hook"], e["hook"], "%s hook" % name)
		for key in ["W_kg", "Fmax_kgf", "E0", "Beff", "spike", "Tbar", "t_tire", "t_reel", "t_fight"]:
			assert_near(r["fight"][key], e[key], "%s %s" % [name, key])
		assert_eq(r["fight"]["line_breaks"], e["line_breaks"], "%s line breaks" % name)
		assert_near(r["landing"]["landing_q"], e["landing_q"], "%s landing" % name)
		assert_near(r["landing"]["visible_at_m"], e["visible_at_m"], "%s visible at" % name)
		assert_near(r["chain"]["p_land_given_take"], e["p_land_given_take"], "%s p_land" % name)
		var total := CatchModelScript.total_take_rate(ctx, _k, species_list)
		assert_near(total, e["total_take_rate_all_species"], "%s total take rate" % name)
		assert_near(CatchModelScript.median_wait_s(total), e["median_wait_all_species_s"], "%s median wait" % name)


func test_prd_calibration_targets() -> void:
	_setup()
	var by_name := {}
	for example: Dictionary in _examples():
		var ctx := _ctx(example)
		by_name[example["name"]] = CatchModelScript.median_wait_s(CatchModelScript.total_take_rate(ctx, _k, _db["species"]))
	assert_true(by_name["A"] >= 20.0 and by_name["A"] <= 40.0, "best case median wait is 20-40 s (PRD F6), got %s" % str(by_name["A"]))
	assert_true(by_name["B"] >= 120.0, "worst case median wait is at least 120 s (PRD F6), got %s" % str(by_name["B"]))


func test_line_break_example() -> void:
	_setup()
	var results := {}
	for example: Dictionary in _examples():
		results[example["name"]] = CatchModelScript.resolve(_ctx(example), _k)
	assert_true(results["C"]["fight"]["line_breaks"], "C: drag 2.6 kg breaks the line")
	assert_near(results["C"]["chain"]["p_land_given_take"], 0.0, "C: a broken line never lands")
	assert_true(not results["C2"]["fight"]["line_breaks"], "C2: drag 1.2 kg holds")
	assert_true(results["C2"]["chain"]["p_land_given_take"] > 0.5, "C2: the fish can be landed")
	assert_true(results["C2"]["fight"]["spike"] < results["C2"]["fight"]["Beff"], "C2: spike is under the real line strength")


func test_every_stage_logs_its_inputs() -> void:
	_setup()
	var r := CatchModelScript.resolve(_ctx(_examples()[0]), _k)
	for stage in ["environment", "presence", "attraction", "commit", "hook", "fight", "landing", "chain"]:
		assert_true(r[stage].has("inputs") and not (r[stage]["inputs"] as Dictionary).is_empty(), "stage %s logs its inputs" % stage)


func test_fight_cap_flag_over_species_and_sizes() -> void:
	_setup()
	var base := _ctx(_examples()[0])
	var capped_seen := false
	var uncapped_seen := false
	for tackle in ["lrf", "spin"]:
		var ctx := _ctx({"species": "istavrit", "position": "pier_end", "tackle": tackle, "conditions": base["conditions"], "play": base["play"]})
		for sp: Dictionary in _db["species"]:
			for length in [sp["length_min_cm"], (float(sp["length_min_cm"]) + float(sp["length_max_cm"])) / 2.0, sp["length_max_cm"]]:
				var c := ctx.duplicate(true)
				c["species"] = sp
				var play: Dictionary = (c["play"] as Dictionary).duplicate()
				play["fish_length_cm"] = length
				c["play"] = play
				var weakest: float = CatchModelScript.fight(_k, sp, c["position"], c["reel"], c["line"], c["leader"], c["angler"], play)["Beff"]
				play["drag_kg"] = weakest / 3.0
				var f := CatchModelScript.fight(_k, sp, c["position"], c["reel"], c["line"], c["leader"], c["angler"], play)
				assert_true(f["t_fight_capped"] <= 90.0, "%s %s %s cm: capped fight is at most 90 s" % [tackle, sp["id"], str(length)])
				assert_true(not f["line_breaks"], "%s %s %s cm: a drag of a third of the line strength holds" % [tackle, sp["id"], str(length)])
				assert_eq(f["cap_applied"], f["t_fight"] > 90.0, "cap flag matches the estimate")
				capped_seen = capped_seen or f["cap_applied"]
				uncapped_seen = uncapped_seen or not f["cap_applied"]
	assert_true(capped_seen, "light tackle on the biggest fish needs the 90 s rule (documented in data_model.md)")
	assert_true(uncapped_seen, "ordinary fights stay under the cap")


func test_resolution_is_deterministic_and_pure() -> void:
	_setup()
	var ctx := _ctx(_examples()[1])
	var before := ctx.duplicate(true)
	var a := CatchModelScript.resolve(ctx, _k)
	var b := CatchModelScript.resolve(ctx, _k)
	assert_eq(a, b, "same inputs give identical results")
	assert_eq(ctx, before, "resolve does not modify its inputs")
