extends "res://tests/test_base.gd"
## The fight screen's logic: frame-rate independence, input mapping, the data
## it hides and the demo data it runs on.

const DEMO_DIR := "res://data/demo"
const CONDITIONS := {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 3}

var _db: Dictionary
var _k: Dictionary


func _setup() -> void:
	var loaded := DataStore.load_all(DEMO_DIR)
	_db = loaded["database"]
	var errors: Array[String] = []
	_k = DataStore.load_constants(errors)


func _ctx(species: String, tackle: String, u: float = 0.1) -> Dictionary:
	return FightSetup.build(_db, species, tackle, "pier_end", u, CONDITIONS)


func _run(frame_s: float, ctx: Dictionary, seed_value: int, drag: float) -> Dictionary:
	var c := FightController.new(ctx, _k, seed_value)
	var hud := c.hud()
	var guard := 0
	while hud["outcome"] == "" and guard < 200000:
		hud = c.advance(frame_s, {"reel": 1.0, "rod": 0.0, "drag_kg": drag})
		guard += 1
	return hud


func test_demo_data_is_valid_and_labelled() -> void:
	var loaded := DataStore.load_all(DEMO_DIR)
	assert_true(loaded["ok"], "demo data validates: %s" % str(loaded["errors"]))
	for entity: String in loaded["database"]:
		for record: Dictionary in loaded["database"][entity]:
			assert_true(record["provenance"]["default"].get("design_fill", false) == true, "%s:%s is labelled a design fill" % [entity, record["id"]])
			assert_true(str(record["name_key"]).begins_with("DEMO_"), "%s:%s uses a DEMO_ name key" % [entity, record["id"]])


func test_demo_name_keys_exist_in_every_language() -> void:
	var loaded := DataStore.load_all(DEMO_DIR)
	var keys := {}
	var file := FileAccess.open("res://locale/translations.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 4:
			keys[row[0]] = true
	var errors := DataValidator.validate_database(loaded["database"], DataStore.read_json(DataStore.SCHEMA_PATH, []), keys)
	assert_true(errors.is_empty(), "every demo name_key is in the translation table: %s" % str(errors))


func test_same_fight_at_any_frame_rate() -> void:
	_setup()
	var ctx := _ctx("istavrit", "lrf")
	var slow := _run(1.0 / 30.0, ctx, 5, 0.8)
	var fast := _run(1.0 / 144.0, ctx, 5, 0.8)
	var odd := _run(0.0173, ctx, 5, 0.8)
	assert_eq(slow["outcome"], fast["outcome"], "30 fps and 144 fps give the same outcome")
	assert_eq(slow["outcome"], odd["outcome"], "an irregular frame time gives the same outcome")
	assert_near(slow["time_s"], fast["time_s"], "and the same fight time", 1e-9)
	assert_near(slow["max_tension_kg"], fast["max_tension_kg"], "and the same peak tension", 1e-9)


func test_long_frames_do_not_skip_a_fight() -> void:
	_setup()
	var c := FightController.new(_ctx("istavrit", "lrf"), _k, 5)
	var hud := c.advance(5.0, {"reel": 1.0, "rod": 0.0, "drag_kg": 0.8})
	assert_true(hud["time_s"] <= FightController.MAX_FRAME_S + FightSim.DT, "a stalled frame advances at most 0.25 s, got %s" % str(hud["time_s"]))


func test_screen_does_not_receive_the_fish_energy() -> void:
	_setup()
	var hud := FightController.new(_ctx("lufer", "lrf"), _k, 1).hud()
	for key: String in hud:
		assert_true(not key.contains("energy"), "HUD key %s does not leak the fish's energy" % key)
	assert_true(hud.has("tension_kg") and hud.has("distance_m") and hud.has("line_strength_kg"), "but shows tension, distance and line strength")


func test_input_mapping() -> void:
	assert_near(FightController.reel_from_pad(false, 10.0, 300.0), 0.0, "not touching, no reel")
	assert_near(FightController.reel_from_pad(true, 0.0, 300.0), 1.0, "top of the pad, full reel")
	assert_near(FightController.reel_from_pad(true, 150.0, 300.0), 0.5, "middle, half")
	assert_near(FightController.reel_from_pad(true, 400.0, 300.0), 0.0, "below the pad clamps to zero")
	assert_near(FightController.drag_from_slider(0.5, 3.0), 1.5, "drag slider maps to the reel's range")
	assert_near(FightController.drag_from_slider(2.0, 3.0), 3.0, "and clamps at the reel's maximum")
	assert_near(FightController.rod_from_button(true), 1.0, "rod pull held")
	assert_near(FightController.rod_from_button(false), 0.0, "rod pull released")


func test_fish_hidden_until_inside_the_visibility_distance() -> void:
	_setup()
	var c := FightController.new(_ctx("istavrit", "lrf"), _k, 5)
	var first := c.hud()
	assert_true(first["distance_m"] > c.visible_at_m and not first["fish_visible"], "at 26 m the fish is not visible")
	var seen := false
	var hud := first
	var guard := 0
	while hud["outcome"] == "" and guard < 50000:
		hud = c.advance(1.0 / 60.0, {"reel": 1.0, "rod": 0.0, "drag_kg": 0.8})
		if hud["fish_visible"]:
			seen = true
			assert_true(hud["distance_m"] <= c.visible_at_m or hud["in_landing"], "visible only inside the visibility distance or while landing")
		guard += 1
	assert_true(seen, "the fish shows itself near the shore")


func test_setup_draws_a_size_inside_the_species_range() -> void:
	_setup()
	for u in [0.0, 0.5, 1.0]:
		var ctx := _ctx("lufer", "spin", u)
		var l: float = ctx["play"]["fish_length_cm"]
		assert_true(l >= ctx["species"]["length_min_cm"] and l <= ctx["species"]["length_max_cm"], "size %s within the range" % str(l))
	assert_true(float(_ctx("lufer", "spin", 0.5)["play"]["drag_kg"]) < float(_ctx("lufer", "spin", 0.5)["reel"]["drag_max_kg"]), "the starting drag is below the reel's maximum")


func test_every_species_and_tackle_can_be_fought() -> void:
	_setup()
	for sp in ["istavrit", "lufer", "levrek"]:
		for tk in FightSetup.TACKLES:
			var ctx := _ctx(sp, tk, 0.3)
			var hud := _run(1.0 / 60.0, ctx, 3, float(ctx["play"]["drag_kg"]))
			assert_true(hud["outcome"] != "", "%s on %s ends: %s" % [sp, tk, str(hud["outcome"])])
