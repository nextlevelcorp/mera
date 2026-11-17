extends "res://tests/test_base.gd"
## The player's "why" view (PRD F10) and the player settings.

var _db: Dictionary
var _k: Dictionary


func _init() -> void:
	_db = DataStore.load_all("res://data")["database"]
	_k = DataStore.load_constants()


func _ctx(species: String, tackle: String) -> Dictionary:
	var cond := {"slot": "evening", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	return FightSetup.build(_db, species, tackle, "karakoy_east", 0.5, cond)


func _stats(outcome_extra: Dictionary = {}) -> Dictionary:
	var s := {"max_tension_kg": 1.4, "drag_kg": 1.0, "line_strength_kg": 2.1, "distance_m": 0.0, "cap_applied": false}
	s.merge(outcome_extra, true)
	return s


func test_grades_use_words_not_colour() -> void:
	assert_eq(WhyReport.grade_key(0.9), "WHY_GOOD", "high fit is good")
	assert_eq(WhyReport.grade_key(0.5), "WHY_FAIR", "middle fit is fair")
	assert_eq(WhyReport.grade_key(0.1), "WHY_POOR", "low fit is poor")


func test_why_has_five_lines_with_matching_arguments() -> void:
	var ctx := _ctx("istavrit", "lrf")
	var resolved := CatchModel.resolve(ctx, _k)
	var csv := FileAccess.get_file_as_string("res://locale/translations.csv")
	for outcome: String in [FightSim.OUTCOME_LANDED, FightSim.OUTCOME_LINE_BREAK, FightSim.OUTCOME_LEADER_CUT, FightSim.OUTCOME_HOOK_PULLED, FightSim.OUTCOME_LOST_AT_EDGE]:
		var lines := WhyReport.lines(resolved, ctx, "Horse mackerel", "Evening", outcome, _stats())
		assert_eq(lines.size(), 5, "%s: depth, time, tackle, line and the reason" % outcome)
		for l: Dictionary in lines:
			assert_true(csv.contains("\n%s," % l["key"]), "%s is in translations.csv" % l["key"])
			for a: Variant in l["args"]:
				if typeof(a) == TYPE_STRING and (a as String).begins_with("WHY_"):
					assert_true(csv.contains("\n%s," % a), "grade key %s is translated" % a)


func test_every_why_string_formats_in_every_language() -> void:
	var ctx := _ctx("lufer", "spin")
	var resolved := CatchModel.resolve(ctx, _k)
	for locale: String in ["en", "tr", "es"]:
		TranslationServer.set_locale(locale)
		for outcome: String in [FightSim.OUTCOME_LANDED, FightSim.OUTCOME_LINE_BREAK, FightSim.OUTCOME_LEADER_CUT, FightSim.OUTCOME_HOOK_PULLED, FightSim.OUTCOME_LOST_AT_EDGE]:
			for l: Dictionary in WhyReport.lines(resolved, ctx, "X", "Y", outcome, _stats()):
				var args: Array = []
				for a: Variant in l["args"]:
					args.append(TranslationServer.translate(a) if (typeof(a) == TYPE_STRING and (a as String).begins_with("WHY_")) else a)
				var text := TranslationServer.translate(l["key"])
				assert_true(text != l["key"], "%s has a %s translation" % [l["key"], locale])
				var problem := _format_problem(text, args)
				assert_eq(problem, "", "%s in %s: %s" % [l["key"], locale, problem])
	TranslationServer.set_locale("en")


## The engine only logs a formatting error and carries on, so check the
## format string against the arguments ourselves: same count, and a number for
## every numeric placeholder, in order.
func _format_problem(text: String, args: Array) -> String:
	var re := RegEx.new()
	re.compile("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?([sdf])|%%")
	var specs: Array[String] = []
	for m in re.search_all(text):
		if m.get_string() != "%%":
			specs.append(m.get_string(1))
	if specs.size() != args.size():
		return "%d placeholders but %d arguments" % [specs.size(), args.size()]
	for i in specs.size():
		var is_number: bool = typeof(args[i]) in [TYPE_INT, TYPE_FLOAT]
		if specs[i] != "s" and not is_number:
			return "placeholder %d wants a number but gets %s" % [i + 1, str(args[i])]
	return ""


func test_reason_follows_the_outcome() -> void:
	var ctx := _ctx("istavrit", "lrf")
	var resolved := CatchModel.resolve(ctx, _k)
	var slack := WhyReport.lines(resolved, ctx, "H", "E", FightSim.OUTCOME_HOOK_PULLED, _stats())[4]
	assert_eq(slack["key"], "WHY_OUT_HOOK_SLACK", "a pulled hook without the cap is the slack-line reason")
	var cap := WhyReport.lines(resolved, ctx, "H", "E", FightSim.OUTCOME_HOOK_PULLED, _stats({"cap_applied": true, "distance_m": 38.0}))[4]
	assert_eq(cap["key"], "WHY_OUT_HOOK_CAP", "with the cap it is the 90 s reason")
	assert_near(float(cap["args"][0]), 38.0, "and names the distance", 0.001)
	var brk := WhyReport.lines(resolved, ctx, "H", "E", FightSim.OUTCOME_LINE_BREAK, _stats({"max_tension_kg": 2.4}))[4]
	assert_near(float(brk["args"][0]), 2.4, "a line break names the peak tension", 0.001)


func test_depth_line_reads_the_models_numbers() -> void:
	var ctx := _ctx("istavrit", "lrf")
	var resolved := CatchModel.resolve(ctx, _k)
	var l := WhyReport.lines(resolved, ctx, "H", "E", FightSim.OUTCOME_LANDED, _stats())[0]
	assert_near(float(l["args"][2]), float(ctx["species"]["feeding_depth_min_m"]), "feeding depth floor from the species data", 0.001)
	assert_near(float(l["args"][4]), float(ctx["play"]["lure_depth_m"]), "lure depth from the play", 0.001)


func test_old_saves_get_default_settings_and_values_are_clamped() -> void:
	var old := {"version": 1, "log": {}, "last_rig": "lrf", "last_position": "karakoy_east"}
	assert_eq(SaveGame.from_data(old)["status"], SaveGame.STATUS_MIGRATED, "a version 1 save without settings still loads (migrated to version 2)")
	assert_near(float(SaveGame.settings_of(old)["volume"]), 0.8, "default volume", 1e-6)
	var s := SaveGame.fresh()
	SaveGame.set_setting(s, "volume", 5.0)
	SaveGame.set_setting(s, "motion_sens", 0.01)
	SaveGame.set_setting(s, "motion_flip", true)
	var st := SaveGame.settings_of(s)
	assert_near(float(st["volume"]), 1.0, "volume clamped to 1", 1e-6)
	assert_near(float(st["motion_sens"]), 0.5, "sensitivity clamped to 0.5", 1e-6)
	assert_eq(st["motion_flip"], true, "flip kept")
	var junk := {"settings": {"volume": "loud", "motion_sens": null, "motion_flip": 3}}
	assert_eq(SaveGame.settings_of(junk), SaveGame.default_settings(), "wrong types fall back to defaults")


func test_sensitivity_changes_what_counts_as_a_strike_and_a_pull() -> void:
	var calm := MotionGesture.new()
	calm.sensitivity = 0.5
	calm.calibrate(0.0)
	assert_true(not calm.add_sample(1.0 / 60.0, 5.0, 0.0)["strike"], "low sensitivity needs a harder flick")
	var keen := MotionGesture.new()
	keen.sensitivity = 2.0
	keen.calibrate(0.0)
	assert_true(keen.add_sample(1.0 / 60.0, 2.5, 0.0)["strike"], "high sensitivity strikes on a gentler flick")
	var a := MotionGesture.new()
	var b := MotionGesture.new()
	b.sensitivity = 2.0
	a.calibrate(0.0)
	b.calibrate(0.0)
	assert_true(float(b.add_sample(1.0 / 60.0, 0.0, 0.3)["pull"]) > float(a.add_sample(1.0 / 60.0, 0.0, 0.3)["pull"]), "the same tilt pulls harder at high sensitivity")


func test_settings_reach_the_gesture_the_motion_and_the_sound() -> void:
	var screen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	screen._change_setting("motion_sens", 2.0)
	assert_near(screen._gesture.sensitivity, 2.0, "sensitivity reaches the gesture rules", 1e-6)
	screen._change_setting("volume", 0.0)
	assert_true(AudioServer.get_bus_volume_db(0) < -60.0, "volume zero silences the master bus")
	screen._change_setting("volume", 0.5)
	assert_near(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), "volume half is -6 dB", 0.01)
	screen._motion.default_invert = true
	screen._change_setting("motion_flip", true)
	assert_true(not screen._motion.invert, "the flip setting reverses the platform default (iPhone inverted + flip = normal)")
	screen._change_setting("motion_flip", false)
	assert_true(screen._motion.invert, "and back")
	assert_near(screen._vol_slider.value, 0.5, "the slider shows the saved value", 0.001)
	AudioServer.set_bus_volume_db(0, 0.0)
	screen.free()


func test_why_panel_explains_a_lost_fish() -> void:
	var screen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	var ctx := _ctx("lufer", "lrf")
	screen._fight_ctx = ctx
	screen._controller = FightController.new(ctx, _k, 1)
	screen._hud = screen._controller.hud()
	screen._hud["max_tension_kg"] = 2.6
	screen._hud["drag_set_kg"] = 1.8
	screen._result = {"outcome": FightSim.OUTCOME_LINE_BREAK}
	screen._show_why()
	assert_true(screen._why_panel.visible and not screen._result_panel.visible, "the why panel replaces the result panel")
	var parts: PackedStringArray = screen._why_text.text.split("\n\n")
	assert_eq(parts.size(), 6, "five reasons and the data note")
	assert_true(screen._why_text.text.contains("2.60"), "the peak tension is named")
	assert_true(not screen._why_text.text.contains("WHY_"), "no raw translation key leaks through")
	screen.free()


func test_motion_monitor_text_formats_in_every_language() -> void:
	for locale: String in ["en", "tr", "es"]:
		TranslationServer.set_locale(locale)
		var problem := _format_problem(TranslationServer.translate("SET_MON_TEXT"), [12.0, 0.4, 35.0, 10.0])
		assert_eq(problem, "", "SET_MON_TEXT in %s: %s" % [locale, problem])
	TranslationServer.set_locale("en")


func test_wait_hud_text_formats_in_every_language() -> void:
	for locale: String in ["en", "tr", "es"]:
		TranslationServer.set_locale(locale)
		var problem := _format_problem(TranslationServer.translate("WAIT_HUD"), [3.2, 8.0, 0.6])
		assert_eq(problem, "", "WAIT_HUD in %s: %s" % [locale, problem])
	TranslationServer.set_locale("en")


func test_a_thrown_hook_on_a_jump_has_its_own_reason() -> void:
	var ctx := _ctx("lufer", "spin")
	var resolved := CatchModel.resolve(ctx, _k)
	var stats := _stats()
	stats["thrown_on_jump"] = true
	var last: Dictionary = WhyReport.lines(resolved, ctx, "X", "Y", FightSim.OUTCOME_HOOK_PULLED, stats)[4]
	assert_eq(last["key"], "WHY_OUT_JUMP", "the reason names the jump")
	for locale: String in ["en", "tr", "es"]:
		TranslationServer.set_locale(locale)
		for key: String in ["WHY_OUT_JUMP", "FIGHT_STEER_HINT", "FIGHT_JUMP_HINT", "LAND_REEL", "LAND_WAIT"]:
			assert_true(TranslationServer.translate(key) != key, "%s has a %s translation" % [key, locale])
		assert_eq(_format_problem(TranslationServer.translate("WHY_OUT_JUMP"), last["args"]), "", "WHY_OUT_JUMP formats in %s" % locale)
	TranslationServer.set_locale("en")


func test_side_strain_reads_the_thumb_on_the_pull_pad() -> void:
	assert_eq(FightController.steer_from_pad(105.0, 210.0), 0.0, "the middle is neutral")
	assert_true(FightController.steer_from_pad(10.0, 210.0) < -0.8, "far left pulls left")
	assert_true(FightController.steer_from_pad(200.0, 210.0) > 0.8, "far right pulls right")
	assert_eq(FightController.steer_from_pad(500.0, 210.0), 1.0, "clamped")
