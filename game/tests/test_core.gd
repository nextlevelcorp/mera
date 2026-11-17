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


func test_a_version_1_save_migrates_with_its_log_and_settings() -> void:
	var v1 := {"version": 1, "log": {"istavrit": {"first_seen": "2026-11-13", "count": 4, "best_length_cm": 23.0, "best_weight_kg": 0.11}},
		"last_rig": "spin", "last_position": "karakoy_east", "settings": {"volume": 0.3, "motion_sens": 1.5, "motion_flip": true}}
	var loaded := SaveGame.from_data(v1)
	assert_eq(loaded["status"], SaveGame.STATUS_MIGRATED, "version 1 migrates")
	var s: Dictionary = loaded["save"]
	assert_eq(int(s["version"]), 2, "to version 2")
	assert_eq(int(s["log"]["istavrit"]["count"]), 4, "the log is kept")
	assert_eq(s["last_rig"], "spin", "the rig is kept")
	assert_near(float(SaveGame.settings_of(s)["volume"]), 0.3, "the settings are kept")
	assert_eq((s["inventory"]["items"] as Array).size(), 0, "an empty bag is added")
	assert_eq(int(s["money"]), 0, "and no money")
	assert_eq(int(s["stats"]["casts"]), 0, "and zeroed counters")
	assert_eq(SaveGame.from_data(s)["status"], SaveGame.STATUS_OK, "the migrated save loads as current")
	var broken: Dictionary = s.duplicate(true)
	broken["inventory"] = {"items": [{"id": 5}]}
	assert_eq(SaveGame.from_data(broken)["status"], SaveGame.STATUS_RESET, "a broken bag resets the save")


func test_a_migrated_file_is_backed_up_and_revisions_rise() -> void:
	var path := "user://test_profile_v1.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "log": {}, "last_rig": "lrf", "last_position": ""}))
	f.close()
	Profile.open(path)
	assert_eq(Profile.status, SaveGame.STATUS_MIGRATED, "the old file migrates on open")
	assert_true(FileAccess.file_exists(path + ".bak"), "the old file is kept as a backup")
	Profile.flush()
	Profile.flush()
	Profile.open(path)
	assert_eq(Profile.status, SaveGame.STATUS_OK, "the written file is version 2")
	assert_eq(int(Profile.save["revision"]), 2, "each write raises the revision")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
	Profile.open("")


func test_the_bag_stacks_items_and_keeps_each_fish() -> void:
	var s := SaveGame.fresh()
	Inventory.add(s, "lrf_soft", 3)
	Inventory.add(s, "lrf_soft", 2)
	assert_eq(Inventory.count(s, "lrf_soft"), 5, "stackable items share an entry")
	assert_eq(Inventory.items(s).size(), 1, "one entry")
	assert_true(not Inventory.remove(s, "lrf_soft", 6), "cannot remove more than there are")
	assert_eq(Inventory.count(s, "lrf_soft"), 5, "and nothing is removed then")
	assert_true(Inventory.remove(s, "lrf_soft", 5), "removing all")
	assert_eq(Inventory.items(s).size(), 0, "empties the entry")
	assert_true(not Inventory.remove(s, "nothing"), "an item that is not there cannot be removed")
	Inventory.add_fish(s, "lufer", 31.0, 0.3, "2026-11-17")
	Inventory.add_fish(s, "lufer", 24.0, 0.15, "2026-11-17")
	assert_eq(Inventory.fish_count(s), 2, "each fish is its own entry")
	assert_eq(Inventory.count(s, Inventory.FISH_PREFIX + "lufer"), 2, "counted by species")
	assert_true(SaveGame.is_valid(s), "the save stays valid")


func test_a_result_fills_the_bag_and_the_counters() -> void:
	var s := SaveGame.fresh()
	var r := Game.empty_result()
	r["casts"] = 7
	r["time_s"] = 312.6
	r["catches"] = [{"species_id": "istavrit", "length_cm": 18.0, "weight_kg": 0.06, "kept": true}, {"species_id": "lufer", "length_cm": 20.0, "weight_kg": 0.1, "kept": false}]
	r["lost"] = [{"item_id": "lrf_soft", "reason": "line_break"}]
	r["events"] = [{"type": "landed", "species_id": "istavrit"}, {"type": "landed", "species_id": "lufer"}, {"type": "line_break", "species_id": "lufer"}]
	SaveGame.apply_result(s, r, "2026-11-17")
	assert_eq(Inventory.fish_count(s), 1, "only kept fish go to the bag")
	assert_eq(Inventory.items(s)[0]["meta"]["caught_at"], "2026-11-17", "with the date")
	assert_eq(int(s["stats"]["casts"]), 7, "casts")
	assert_eq(int(s["stats"]["fish_landed"]), 2, "landed")
	assert_eq(int(s["stats"]["fish_lost"]), 1, "lost")
	assert_eq(int(s["stats"]["lures_lost"]), 1, "lures lost")
	assert_eq(int(s["stats"]["play_s"]), 312, "seconds played")
	assert_true(SaveGame.is_valid(s), "the save stays valid")


func test_the_session_owns_the_rules_of_a_visit() -> void:
	var db := Db.database()
	var pos: String = db["spot"][0]["positions"][0]["id"]
	var species_id: String = db["spot"][0]["species"][0]["species_id"]
	var cond := {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 3}
	var a := FishingSession.new(db, Db.constants(), "lrf", pos, cond)
	var b := FishingSession.new(db, Db.constants(), "lrf", pos, cond)
	var ctx := a.context(species_id)
	var cast := a.cast(ctx, 0.9)
	assert_true(float(cast["cast_m"]) >= float(Db.constants()["WAIT_END_M"]) + 2.0, "a cast is never shorter than the retrieve's end")
	assert_eq(int(a.result()["casts"]), 1, "the cast is counted")
	b.cast(b.context(species_id), 0.9)
	var wa := a.start_wait(ctx, float(cast["cast_m"]), 0.1)
	var wb := b.start_wait(ctx, float(cast["cast_m"]), 0.1)
	for i in 600:
		wa.advance(1.0 / 30.0, {"reel": 0.2})
		wb.advance(1.0 / 30.0, {"reel": 0.2})
	assert_eq(wa.events, wb.events, "two sessions with the same history wait the same way")
	var fight_ctx := a.fight_context({"species_id": species_id, "u": 0.5, "timing_quality": 0.8, "hook": 0.9, "distance_m": 14.0, "lure_depth_m": 2.5, "retrieve_speed": 6.0})
	assert_near(float(fight_ctx["play"]["lure_depth_m"]), 2.5, "the fight knows the depth the fish took at")
	assert_true(a.start_fight(fight_ctx).sim.weight_kg > 0.0, "a fight starts")
	a.record_outcome(FightSim.OUTCOME_LINE_BREAK, fight_ctx, 0.1)
	a.add_time(12.5)
	var r := a.result()
	assert_eq(r["lost"][0]["item_id"], fight_ctx["lure"]["id"], "a broken line loses the lure")
	assert_eq((r["catches"] as Array).size(), 0, "and lands nothing")
	assert_near(float(r["time_s"]), 12.5, "time is kept")
	var clarity := float(db["spot"][0]["typical_clarity"])
	a.clarity_override = clarity + 1.0
	assert_near(float(a.context(species_id)["spot"]["typical_clarity"]), clarity + 1.0, "the debug clarity replaces the spot's")
	assert_near(float(db["spot"][0]["typical_clarity"]), clarity, "without changing the data")
