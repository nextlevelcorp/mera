extends "res://tests/test_base.gd"
## Attribute database: schema, validator and loader (docs/data_model.md sections 2-4).
## The fixtures are illustrative design fills, not real data.

const FIXTURE_DIR := "res://tests/fixtures"

var _schema: Dictionary
var _known_keys: Dictionary


func _load() -> Dictionary:
	var errors: Array[String] = []
	_schema = DataStore.read_json(DataStore.SCHEMA_PATH, errors)
	var first: Dictionary = DataStore.load_all(FIXTURE_DIR)
	_known_keys = {}
	_collect_keys(first["database"], _known_keys)
	return DataStore.load_all(FIXTURE_DIR, _known_keys)


func _collect_keys(node: Variant, keys: Dictionary) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for key: String in node:
			if key == "name_key":
				keys[node[key]] = true
			else:
				_collect_keys(node[key], keys)
	elif typeof(node) == TYPE_ARRAY:
		for item: Variant in node:
			_collect_keys(item, keys)


func _errors_for(mutate: Callable) -> Array[String]:
	var loaded := _load()
	var database: Dictionary = loaded["database"]
	mutate.call(database)
	return DataValidator.validate_database(database, _schema, _known_keys)


func _has(errors: Array[String], fragment: String) -> bool:
	for e in errors:
		if e.contains(fragment):
			return true
	return false


func _expect(mutate: Callable, fragment: String, label: String) -> void:
	var errors := _errors_for(mutate)
	assert_true(_has(errors, fragment), "%s should report '%s', got %s" % [label, fragment, str(errors)])


func test_schema_and_constants_load() -> void:
	var errors: Array[String] = []
	var schema = DataStore.read_json(DataStore.SCHEMA_PATH, errors)
	assert_true(errors.is_empty(), "schema.json loads: %s" % str(errors))
	for entity in ["species", "spot", "position", "rod", "reel", "line", "leader", "lure", "bait", "angler"]:
		assert_true(schema["entities"].has(entity), "schema defines %s" % entity)
	var k := DataStore.load_constants(errors)
	for key in ["R0", "LIGHT", "CHOP_CLARITY", "FIGHT_CAP_S", "LAND_PHASE", "TW_BASE", "HOOK_MAX", "COMMIT_MIN"]:
		assert_true(k.has(key), "constants.json has %s" % key)
	assert_eq(float(k["FIGHT_CAP_S"]), 90.0, "fight cap is 90 s (PRD F8)")


func test_fixtures_are_valid() -> void:
	var loaded := _load()
	assert_true(loaded["ok"], "fixtures validate: %s" % str(loaded["errors"]))
	assert_eq((loaded["database"]["species"] as Array).size(), 3, "three fixture species")
	assert_eq(((loaded["database"]["spot"] as Array)[0]["positions"] as Array).size(), 3, "three positions")


func test_every_fixture_record_is_labelled_design_fill() -> void:
	var loaded := _load()
	for entity: String in loaded["database"]:
		for record: Dictionary in loaded["database"][entity]:
			assert_true(record["provenance"]["default"].get("design_fill", false) == true, "%s:%s is a design fill" % [entity, record["id"]])


func test_missing_provenance_fails() -> void:
	_expect(func(db): (db["species"][0] as Dictionary).erase("provenance"), "missing provenance", "missing provenance")


func test_source_needs_accessed_date_and_exclusive_choice() -> void:
	_expect(func(db): db["species"][0]["provenance"] = {"default": {"source": "Author (2020)"}}, "accessed date", "source without date")
	_expect(func(db): db["species"][0]["provenance"] = {"default": {"design_fill": true, "source": "x", "accessed": "2026-01-01"}}, "exactly one", "both")
	_expect(func(db): db["species"][0]["provenance"] = {"default": {"source": "  ", "accessed": "2026-01-01"}}, "exactly one", "blank source")
	var ok := _errors_for(func(db): db["species"][0]["provenance"] = {"default": {"design_fill": true}, "fields": {"lw_a": {"source": "Author (2020), p. 4", "accessed": "2026-11-11"}}})
	assert_true(ok.is_empty(), "a per-field source plus a default fill is valid: %s" % str(ok))
	_expect(func(db): db["species"][0]["provenance"] = {"default": {"design_fill": true}, "fields": {"nope": {"design_fill": true}}}, "not a field", "provenance for an unknown field")


func test_range_type_and_enum_checks() -> void:
	_expect(func(db): db["species"][0]["strength"] = 21, "above the maximum", "attribute 21")
	_expect(func(db): db["species"][0]["strength"] = 0, "below the minimum", "attribute 0")
	_expect(func(db): db["species"][0]["strength"] = 5.5, "whole number", "fractional attribute")
	_expect(func(db): (db["species"][0] as Dictionary).erase("teeth"), "missing required field", "teeth is required")
	_expect(func(db): db["species"][0]["strength"] = "6", "whole number", "string attribute")
	_expect(func(db): db["species"][0]["diet_tags"] = ["rocks"], "is not one of", "bad diet tag")
	_expect(func(db): db["lure"][0]["type"] = "boat", "is not one of", "bad lure type")
	_expect(func(db): db["species"][0]["id"] = "Bad Id", "does not match", "bad id pattern")


func test_missing_and_unknown_fields_fail() -> void:
	_expect(func(db): (db["species"][0] as Dictionary).erase("mouth_gape_mm"), "missing required field", "missing field")
	_expect(func(db): db["species"][0]["strenght"] = 5, "unknown field", "typo field")
	_expect(func(db): (db["species"][0]["activity_by_slot"] as Dictionary).erase("night"), "missing key night", "slot missing")
	_expect(func(db): (db["spot"][0]["positions"][0]["exposure_by_wind"] as Dictionary).erase("SW"), "missing key SW", "wind missing")
	_expect(func(db): db["spot"][0]["positions"][0]["facing"] = "UP", "is not one of", "bad facing")


func test_ordering_rules() -> void:
	_expect(func(db): db["species"][0]["feeding_depth_min_m"] = 20.0, "feeding_depth_min_m must be less", "depth order")
	_expect(func(db): db["species"][0]["temp_min_c"] = 30.0, "temp_min_c must be less", "temp order")
	_expect(func(db): db["species"][0]["length_min_cm"] = 50.0, "length_min_cm must be less", "length order")
	_expect(func(db): db["species"][0]["length_record_cm"] = 10.0, "length_record_cm must be at least", "record length")
	_expect(func(db): db["rod"][0]["cast_weight_min_g"] = 99.0, "cast_weight_min_g must be less", "cast weights")


func test_cross_reference_and_uniqueness_rules() -> void:
	_expect(func(db): db["species"][1]["id"] = db["species"][0]["id"], "duplicate id", "duplicate species id")
	_expect(func(db): db["spot"][0]["species"][0]["species_id"] = "ghost_fish", "unknown species_id", "unknown species ref")
	_expect(func(db): db["spot"][0]["species"].append(db["spot"][0]["species"][0].duplicate(true)), "listed twice", "species listed twice")
	_expect(func(db): db["spot"][0]["water_class"] = "fresh", "does not live in fresh water", "water class mismatch")
	_expect(func(db): db["species"][0]["name_key"] = "NOT_IN_TABLE", "not in the localisation table", "unknown name_key")


func test_position_rules() -> void:
	_expect(func(db): (db["spot"][0]["positions"] as Array).pop_back(), "needs at least 3 items", "two positions")
	_expect(func(db):
		var positions: Array = db["spot"][0]["positions"]
		positions.append((positions[0] as Dictionary).duplicate(true))
		positions.append((positions[1] as Dictionary).duplicate(true)),
		"allows at most 4", "five positions")
	_expect(func(db):
		var p: Array = db["spot"][0]["positions"]
		p[1]["depth_profile"] = (p[0]["depth_profile"] as Array).duplicate(true)
		p[1]["structure"] = p[0]["structure"],
		"shares depth profile and structure", "indistinguishable positions")
	_expect(func(db): db["spot"][0]["positions"][0]["depth_profile"] = [{"distance_m": 10, "depth_m": 2}, {"distance_m": 5, "depth_m": 4}], "distances must increase", "unsorted profile")
	_expect(func(db): db["spot"][0]["positions"][0]["depth_profile"] = [{"distance_m": 0, "depth_m": 2}], "needs at least 2 items", "one-point profile")


func test_loader_reports_missing_and_broken_files() -> void:
	var missing := DataStore.load_all("res://tests/fixtures_that_do_not_exist")
	assert_true(not missing["ok"], "a missing data directory fails")
	assert_true(_has(missing["errors"], "file not found"), "missing file is named: %s" % str(missing["errors"]))
	var errors: Array[String] = []
	DataStore.read_json("res://tests/test_base.gd", errors)
	assert_true(_has(errors, "invalid JSON"), "non-JSON content is reported")
