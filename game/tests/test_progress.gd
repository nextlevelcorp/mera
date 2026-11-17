extends "res://tests/test_base.gd"
## Roadmap R9: experience, skill levels and the attributes they raise.


func _k() -> Dictionary:
	return Db.constants()


func test_levels_follow_the_curve_and_stop_at_the_top() -> void:
	var k := _k()
	assert_eq(Progress.level(k, 0), 1, "everyone starts at level 1")
	assert_eq(Progress.level(k, Progress.xp_for_level(k, 2) - 1), 1, "one point short of level 2")
	assert_eq(Progress.level(k, Progress.xp_for_level(k, 2)), 2, "level 2 at its threshold")
	assert_eq(Progress.level(k, Progress.xp_for_level(k, 5)), 5, "level 5 at its threshold")
	assert_eq(Progress.level(k, 10000000), Progress.MAX_LEVEL, "capped")
	assert_true(Progress.xp_for_level(k, 3) - Progress.xp_for_level(k, 2) > Progress.xp_for_level(k, 2), "each level asks for more")


func test_events_earn_the_right_skill() -> void:
	var k := _k()
	assert_eq(Progress.points(k, {"type": "cast", "power": 0.5}), {"cast": int(k["XP_CAST"])}, "a cast earns casting")
	assert_eq(int(Progress.points(k, {"type": "cast", "power": 0.95})["cast"]), int(k["XP_CAST"]) + int(k["XP_CAST_GOOD"]), "a release at the top earns more")
	var poor := int(Progress.points(k, {"type": "hooked", "timing": 0.1})["strike"])
	var sharp := int(Progress.points(k, {"type": "hooked", "timing": 1.0})["strike"])
	assert_true(sharp > poor, "a well-timed strike earns more (%d against %d)" % [sharp, poor])
	assert_true(int(Progress.points(k, {"type": "landed", "peak_ratio": 0.9})["knots"]) > int(Progress.points(k, {"type": "landed", "peak_ratio": 0.2})["knots"]), "a knot that held under load earns more")
	assert_true(Progress.points(k, {"type": "nothing"}).is_empty(), "an unknown event earns nothing")


func test_awards_accumulate_and_report_level_ups() -> void:
	var k := _k()
	var s := SaveGame.fresh()
	var ups := 0
	for i in 30:
		var r := Progress.award(s, k, {"type": "hooked", "timing": 1.0})
		ups += (r["level_ups"] as Array).size()
	assert_eq(Progress.xp(s, "strike"), 30 * (int(k["XP_STRIKE"]) + int(k["XP_STRIKE_TIMING"])), "experience adds up")
	assert_eq(ups, Progress.level(k, Progress.xp(s, "strike")) - 1, "every level up is reported once")
	assert_eq(Progress.xp(s, "cast"), 0, "other skills are untouched")
	assert_true(SaveGame.is_valid(s) and SaveGame.from_data(JSON.parse_string(JSON.stringify(s)))["status"] == SaveGame.STATUS_OK, "the save stays valid and loads back")


func test_levels_raise_the_attributes_the_model_reads() -> void:
	var k := _k()
	var base: Dictionary = Db.database()["angler"][0]
	var s := SaveGame.fresh()
	assert_eq(Progress.angler(base, s, k), base, "a new player is the default angler")
	s["angler_xp"] = {"cast": Progress.xp_for_level(k, 4), "knots": Progress.xp_for_level(k, 10) * 10}
	var a := Progress.angler(base, s, k)
	assert_eq(int(a["casting_distance"]), int(base["casting_distance"]) + 3, "cast level 4 adds three to distance")
	assert_eq(int(a["casting_accuracy"]), int(base["casting_accuracy"]) + 3, "and to accuracy")
	assert_eq(int(a["knot_strength"]), mini(int(base["knot_strength"]) + 9, 20), "knots at the top level, capped at 20")
	assert_eq(int(a["strike_timing"]), int(base["strike_timing"]), "strike untouched")
	# The cast model sees it: a better caster throws further at the same power.
	var db := Db.database()
	var ctx := FightSetup.build(db, db["spot"][0]["species"][0]["species_id"], "spin", db["spot"][0]["positions"][0]["id"], 0.5, {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 0})
	var plain := CatchModel.cast(k, ctx["rod"], ctx["lure"], base, ctx["position"], ctx["conditions"], 0.9)
	var skilled := CatchModel.cast(k, ctx["rod"], ctx["lure"], a, ctx["position"], ctx["conditions"], 0.9)
	assert_true(float(skilled["cast_m"]) > float(plain["cast_m"]), "a better caster casts further (%.1f against %.1f m)" % [skilled["cast_m"], plain["cast_m"]])
	assert_true(float(skilled["aim_sigma_rad"]) < float(plain["aim_sigma_rad"]), "and more accurately")


func test_strike_skill_widens_the_window_and_the_default_changes_nothing() -> void:
	var k := _k()
	var base: Dictionary = Db.database()["angler"][0]
	assert_near(Progress.strike_window_factor(k, base), 1.0, "the default angler keeps the model's window")
	var better := base.duplicate()
	better["strike_timing"] = 18
	assert_true(Progress.strike_window_factor(k, better) > 1.0, "a sharper striker gets a longer window")


func test_the_session_uses_the_players_skills() -> void:
	var k := _k()
	var db := Db.database()
	var s := SaveGame.fresh()
	s["angler_xp"] = {"cast": Progress.xp_for_level(k, 6)}
	var session := FishingSession.new(db, k, "spin", db["spot"][0]["positions"][0]["id"], {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 0})
	var plain := session.context(db["spot"][0]["species"][0]["species_id"])
	session.save = s
	var skilled := session.context(db["spot"][0]["species"][0]["species_id"])
	assert_eq(int(skilled["angler"]["casting_distance"]), int(plain["angler"]["casting_distance"]) + 5, "the fishing context carries the levelled angler")


func test_fishing_awards_experience_on_the_screen() -> void:
	var screen: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	screen.cast_with_power(0.95)
	assert_true(Progress.xp(screen.save, "cast") > 0, "a cast earns casting experience")
	screen._land_lure()
	screen._start_fight({"species_id": Db.database()["spot"][0]["species"][0]["species_id"], "u": 0.2, "timing_quality": 0.9, "hook": 0.9, "distance_m": 10.0})
	assert_true(Progress.xp(screen.save, "strike") > 0, "a hooked fish earns strike experience")
	for i in 4000:
		if screen.phase != FishingScreen.Phase.FIGHT:
			break
		var kicking: bool = screen._hud["in_landing"] and screen._hud["kicking"]
		screen.set_fight_input(not kicking, 0.0, false, 0.4)
		screen._step_fight(1.0 / 30.0)
	if screen._result["outcome"] == FightSim.OUTCOME_LANDED:
		assert_true(Progress.xp(screen.save, "knots") > 0, "a landed fish earns knot experience")
		screen._show_result()
		assert_true(screen._ui.result_detail.text.contains(tr("SKILL_CAST")), "the result names the experience gained")
	assert_true(screen.skills_text().contains(tr("SKILL_STRIKE")), "the log lists the skills")
	screen.free()
