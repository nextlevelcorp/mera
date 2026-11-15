extends "res://tests/test_base.gd"
## Conditions from the phone's clock: slot, month and a seeded wind.


func _dt(h: int, m: int = 11, d: int = 15, y: int = 2026) -> Dictionary:
	return {"year": y, "month": m, "day": d, "hour": h}


func test_hours_map_to_slots() -> void:
	assert_eq(SessionConditions.slot_for_hour(4), "night", "04:00 is night")
	assert_eq(SessionConditions.slot_for_hour(5), "dawn", "05:00 is dawn")
	assert_eq(SessionConditions.slot_for_hour(8), "day", "08:00 is day")
	assert_eq(SessionConditions.slot_for_hour(16), "day", "16:00 is day")
	assert_eq(SessionConditions.slot_for_hour(17), "evening", "17:00 is evening")
	assert_eq(SessionConditions.slot_for_hour(20), "night", "20:00 is night")
	assert_eq(SessionConditions.slot_for_hour(0), "night", "midnight is night")


func test_same_date_and_hour_give_the_same_wind() -> void:
	assert_eq(SessionConditions.from_clock(_dt(18)), SessionConditions.from_clock(_dt(18)), "deterministic")
	var winds := {}
	for h in 24:
		winds[str(SessionConditions.from_clock(_dt(h))["wind_dir"]) + str(SessionConditions.from_clock(_dt(h))["wind_ms"])] = true
	assert_true(winds.size() > 4, "the wind changes through the day")


func test_conditions_are_valid_for_the_model() -> void:
	var db: Dictionary = DataStore.load_all("res://data")["database"]
	var k := DataStore.load_constants()
	for day in range(1, 29):
		for h in [3, 6, 12, 18]:
			var c := SessionConditions.from_clock(_dt(h, 1 + day % 12, day))
			assert_true(c["wind_dir"] in CatchModel.WIND_DIRECTIONS, "a known wind direction")
			assert_true(float(c["wind_ms"]) >= 0.5 and float(c["wind_ms"]) <= 12.0, "a wind speed in range")
			var env := CatchModel.environment(k, db["spot"][0], db["spot"][0]["positions"][0], c)
			assert_true(float(env["visibility"]) >= 0.0, "the model accepts it")


func test_prevailing_winds_are_the_istanbul_ones() -> void:
	var ne := 0
	var sw := 0
	var other := 0
	for day in range(1, 29):
		for h in range(24):
			var d: String = SessionConditions.from_clock(_dt(h, 3, day))["wind_dir"]
			if d == "NE":
				ne += 1
			elif d == "SW":
				sw += 1
			else:
				other += 1
	assert_true(ne + sw > other * 0.7, "poyraz and lodos together are about half: %d NE, %d SW, %d others" % [ne, sw, other])


func test_the_screen_uses_the_clock_only_with_a_save() -> void:
	var screen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	assert_eq(screen.conditions["month"], 10, "tests and headless runs keep the fixed conditions")
	screen.free()
