extends "res://tests/test_base.gd"
## Core: shared data, the profile, and the request and result of a fishing session.


func test_db_loads_once_and_finds_records() -> void:
	assert_true(Db.ok(), "the game data loads: %s" % str(Db.errors))
	assert_true(Db.database() == Db.database(), "the same database every time")
	var spot: Dictionary = Db.database()["spot"][0]
	assert_eq(Db.record("spot", spot["id"])["id"], spot["id"], "a record is found by kind and id")
	assert_true(Db.record("spot", "no_such_spot").is_empty(), "an unknown id gives an empty record")
	assert_true(Db.constants().has("FIGHT_CAP_S"), "constants are loaded")


func test_profile_in_memory_does_not_touch_the_disk() -> void:
	Profile.open("")
	assert_true(not Profile.persistent(), "an empty path keeps the save in memory")
	assert_eq(int(Profile.save["version"]), SaveGame.VERSION, "a fresh save")
	Profile.flush()
	assert_true(not FileAccess.file_exists("user://.tmp"), "nothing written")


func test_a_request_sets_the_rig_position_and_conditions() -> void:
	var positions: Array = Db.database()["spot"][0]["positions"]
	var screen: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.request = Game.fishing_request("", positions[1]["id"], "spin", {"slot": "dawn", "month": 5, "wind_dir": "NE", "wind_ms": 6})
	screen.setup("")
	assert_eq(screen.rig, "spin", "rig from the request")
	assert_eq(screen.position_id, positions[1]["id"], "position from the request")
	assert_eq(screen.conditions["slot"], "dawn", "conditions from the request")
	screen.free()
	var plain: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	plain.request = Game.fishing_request("", "nowhere", "harpoon")
	plain.setup("")
	assert_eq(plain.rig, "lrf", "an unknown rig falls back to the saved one")
	assert_eq(plain.position_id, positions[0]["id"], "an unknown position falls back")
	plain.free()


func test_a_session_reports_what_happened() -> void:
	var screen: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	assert_eq(screen.result(), Game.empty_result(), "nothing yet")
	var species_id: String = Db.database()["spot"][0]["species"][0]["species_id"]
	var landed := 0
	for attempt in 12:
		screen.cast_with_power(0.8)
		screen._land_lure()
		screen._start_fight({"species_id": species_id, "u": 0.2, "timing_quality": 0.9, "hook": 0.9, "distance_m": 12.0})
		for i in 4000:
			if screen.phase != FishingScreen.Phase.FIGHT:
				break
			var kicking: bool = screen._hud["in_landing"] and screen._hud["kicking"]
			screen.set_fight_input(not kicking, 0.0, false, 0.4)
			screen._step_fight(1.0 / 30.0)
		if screen._result["outcome"] == FightSim.OUTCOME_LANDED:
			landed += 1
		screen._hud = {}
		screen._set_phase(FishingScreen.Phase.READY)
	var r := screen.result()
	assert_eq(int(r["casts"]), 12, "every cast is counted")
	assert_eq((r["events"] as Array).size(), 12, "every fight leaves an event")
	assert_eq((r["catches"] as Array).size(), landed, "landed fish are in the catches (%d)" % landed)
	assert_true(landed > 0, "the small fish on matched tackle is landed at least once")
	var c: Dictionary = r["catches"][0]
	assert_eq(c["species_id"], species_id, "with its species")
	assert_true(float(c["length_cm"]) > 0.0 and float(c["weight_kg"]) > 0.0, "length and weight")
	r["casts"] = 99
	assert_eq(int(screen.result()["casts"]), 12, "the result is a copy")
	var got := []
	screen.finished.connect(func(res: Dictionary) -> void: got.append(res))
	screen.leave()
	assert_eq(got.size(), 1, "leaving hands the result to whoever opened the session")
	screen.free()
