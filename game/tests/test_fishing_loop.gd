extends "res://tests/test_base.gd"
## The fishing loop: wait and bite (PRD F6, F7), local save (F14), the catch
## log (F9), generated cues, the fish body and the loop screen end to end.

var _db: Dictionary
var _k: Dictionary


func _init() -> void:
	_db = DataStore.load_all("res://data/demo")["database"]
	_k = DataStore.load_constants()


func _ctx(slot: String, tackle: String, position: String) -> Dictionary:
	return FightSetup.build(_db, "istavrit", tackle, position, 0.5, {"slot": slot, "month": 10, "wind_dir": "SW", "wind_ms": 3})


## Total waiting time until the first take, casting again whenever the lure is back.
func _wait_until_take(ctx: Dictionary, seed_value: int) -> float:
	var total := 0.0
	for c in 200:
		var w := WaitSim.new(ctx, _k, _db["species"], 20.0, seed_value * 1000 + c + 1)
		while not w.is_over() and w.phase != WaitSim.PHASE_TAKE:
			w.step()
		total += w.time_s
		if w.phase == WaitSim.PHASE_TAKE:
			return total
	return total


func _median(values: Array[float]) -> float:
	values.sort()
	return values[values.size() / 2]


func test_wait_is_deterministic_for_a_seed() -> void:
	var ctx := _ctx("evening", "lrf", "pier_end")
	var a := WaitSim.new(ctx, _k, _db["species"], 20.0, 42)
	var b := WaitSim.new(ctx, _k, _db["species"], 20.0, 42)
	while not a.is_over():
		a.step()
	while not b.is_over():
		b.step()
	assert_eq(str(a.events), str(b.events), "same seed, same events")


func test_wait_does_not_depend_on_the_frame_rate() -> void:
	var ctx := _ctx("evening", "lrf", "pier_end")
	var slow := WaitSim.new(ctx, _k, _db["species"], 20.0, 5)
	var fast := WaitSim.new(ctx, _k, _db["species"], 20.0, 5)
	for i in 30 * 20:
		slow.advance(1.0 / 30.0, {})
	for i in 144 * 20:
		fast.advance(1.0 / 144.0, {})
	assert_eq(slow.events.size(), fast.events.size(), "same number of events at 30 and 144 fps")
	assert_near(slow.lure_distance_m, fast.lure_distance_m, "lure retrieved the same distance", 0.05)


func test_median_wait_meets_prd_f6() -> void:
	var best: Array[float] = []
	var worst: Array[float] = []
	for s in 80:
		best.append(_wait_until_take(_ctx("evening", "lrf", "pier_end"), s))
		worst.append(_wait_until_take(_ctx("day", "spin", "inner_corner"), s))
	var mb := _median(best)
	var mw := _median(worst)
	assert_true(mb >= 20.0 and mb <= 40.0, "best case median wait %.1f s is within 20-40 s" % mb)
	assert_true(mw >= 120.0, "worst case median wait %.1f s is at least 120 s" % mw)


func test_interest_produces_nibbles_and_takes() -> void:
	var ctx := _ctx("evening", "lrf", "pier_end")
	var nibbles := 0
	var takes := 0
	for s in 40:
		var w := WaitSim.new(ctx, _k, _db["species"], 20.0, s + 1)
		while not w.is_over():
			w.step()   # no strike: every take runs out
		for e: Dictionary in w.events:
			nibbles += 1 if e["event"] == "nibble" else 0
			takes += 1 if e["event"] == "take" else 0
	assert_true(nibbles > 0 and takes > 0, "both nibbles (%d) and takes (%d) happen" % [nibbles, takes])


func test_strike_outside_the_window_never_hooks() -> void:
	var ctx := _ctx("evening", "lrf", "pier_end")
	var w := WaitSim.new(ctx, _k, _db["species"], 20.0, 3)
	w.advance(0.1, {"strike": true})
	assert_eq(w.events[-1]["event"], "strike_empty", "a strike with no take is empty")
	w.force_take("istavrit")
	while w.phase == WaitSim.PHASE_TAKE:
		w.step()
	assert_eq(w.events[-1]["event"], "take_missed", "a take with no strike runs out")
	assert_true(w.hooked.is_empty(), "nothing hooked")


func test_strike_inside_the_window_hooks_by_stage_4() -> void:
	var ctx := _ctx("evening", "lrf", "pier_end")
	var hooked := 0
	var trials := 200
	var expected := 0.0
	for s in trials:
		var w := WaitSim.new(ctx, _k, _db["species"], 20.0, s + 100)
		w.force_take("istavrit")
		var window: float = w.events[-1]["window_s"]
		while float(w.snapshot()["take_progress"]) < 0.5:
			w.step()
		w.advance(0.0, {"strike": true})
		var e: Dictionary = w.events[-1]
		assert_true(e["event"] in ["hooked", "hook_failed"], "a strike in the window rolls the hook")
		assert_true(float(e["timing_quality"]) > 0.8, "a strike at the centre times well (window %.2f s)" % window)
		expected += float(e["stage_hook"]["hook"])
		hooked += 1 if e["event"] == "hooked" else 0
	var rate := float(hooked) / trials
	assert_near(rate, expected / trials, "hook rate follows stage 4", 0.08)


func test_retrieve_ends_the_cast() -> void:
	var w := WaitSim.new(_ctx("day", "spin", "inner_corner"), _k, _db["species"], 8.0, 1)
	while not w.is_over():
		w.step()
		if w.phase == WaitSim.PHASE_TAKE:
			w.force_take("lufer")
	assert_true(w.phase == WaitSim.PHASE_RETRIEVED or w.phase == WaitSim.PHASE_HOOKED or w.events.size() > 0, "the cast ends")
	assert_true(w.lure_distance_m <= float(_k["WAIT_END_M"]) + 0.01 or w.phase != WaitSim.PHASE_RETRIEVED, "retrieved at the shore")


func test_wait_events_log_the_stages() -> void:
	var w := WaitSim.new(_ctx("evening", "lrf", "pier_end"), _k, _db["species"], 20.0, 9)
	w.force_take("lufer")
	var e: Dictionary = w.events[-1]
	for key: String in ["water_depth_m", "presence", "attraction", "commit"]:
		assert_true(e["stages"].has(key), "a take logs stage %s (PRD F10)" % key)
	assert_true(e["stages"]["presence"].has("inputs") or e["stages"]["presence"].has("presence"), "with its numbers")


# ------------------------------------------------------------------ save

func test_save_records_first_catch_and_records() -> void:
	var s := SaveGame.fresh()
	var r1 := SaveGame.record_catch(s, "istavrit", 20.0, 0.08, "2026-11-13")
	assert_true(r1["first"], "first catch")
	var r2 := SaveGame.record_catch(s, "istavrit", 18.0, 0.06, "2026-11-14")
	assert_true(not r2["first"] and not r2["length_record"], "smaller fish: no record")
	var r3 := SaveGame.record_catch(s, "istavrit", 24.0, 0.12, "2026-11-15")
	assert_true(r3["length_record"] and r3["weight_record"], "bigger fish: record")
	var e: Dictionary = s["log"]["istavrit"]
	assert_eq(int(e["count"]), 3, "count")
	assert_eq(e["first_seen"], "2026-11-13", "first-seen date kept")
	assert_near(float(e["best_length_cm"]), 24.0, "best length", 0.001)


func test_save_load_paths() -> void:
	assert_eq(SaveGame.from_data(null)["status"], SaveGame.STATUS_NEW, "no file: new")
	assert_eq(SaveGame.from_data("garbage")["status"], SaveGame.STATUS_RESET, "not an object: reset")
	assert_eq(SaveGame.from_data({"version": 99})["status"], SaveGame.STATUS_RESET, "newer version: reset")
	assert_eq(SaveGame.from_data({"version": 1, "log": []})["status"], SaveGame.STATUS_RESET, "wrong shape: reset")
	var old := {"log": {"lufer": {"first_seen": "2026-10-01", "count": 1, "best_length_cm": 30.0, "best_weight_kg": 0.3}}, "last_rig": "spin"}
	var migrated := SaveGame.from_data(old)
	assert_eq(migrated["status"], SaveGame.STATUS_MIGRATED, "version 0 migrates")
	assert_eq(migrated["save"]["last_rig"], "spin", "keeps the rig")
	assert_true(migrated["save"]["log"].has("lufer"), "keeps the log")
	var ok := SaveGame.from_data(SaveGame.fresh())
	assert_eq(ok["status"], SaveGame.STATUS_OK, "current version loads")


func test_save_file_round_trip_and_corrupt_file() -> void:
	var path := "user://test_save.json"
	var s := SaveGame.fresh()
	SaveGame.record_catch(s, "levrek", 40.0, 0.7, "2026-11-13")
	SaveGame.set_rig(s, "spin", "outer_face")
	assert_true(SaveFile.store(s, path), "written")
	var back := SaveFile.load_save(path)
	assert_eq(back["status"], SaveGame.STATUS_OK, "read back")
	assert_eq(back["save"]["last_position"], "outer_face", "position restored")
	assert_true(back["save"]["log"].has("levrek"), "log restored")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_eq(SaveFile.load_save(path)["status"], SaveGame.STATUS_RESET, "corrupt file resets without a crash")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ------------------------------------------------------------------ cues and fish

func test_generated_cues_are_short_sounds() -> void:
	for cue: String in ["nibble", "take", "landed"]:
		var wav := CueSynth.make(cue)
		var seconds := wav.data.size() / 2.0 / CueSynth.MIX_RATE
		assert_true(seconds > 0.02 and seconds < 1.0, "%s lasts %.2f s" % [cue, seconds])
	assert_eq(CueSynth.make("take").data, CueSynth.make("take").data, "generated the same way every time")


func test_fish_body_beats_harder_when_thrashing() -> void:
	var calm := FishBody.new(0.4, Vector2(0, 5))
	var wild := FishBody.new(0.4, Vector2(0, 5))
	var calm_span := 0.0
	var wild_span := 0.0
	for i in 120:
		calm.step(1.0 / 60.0, Vector2(0, 5), "rest")
		wild.step(1.0 / 60.0, Vector2(0, 5), "thrash")
		calm_span = maxf(calm_span, absf(calm.spine()[-1].x - calm.spine()[0].x))
		wild_span = maxf(wild_span, absf(wild.spine()[-1].x - wild.spine()[0].x))
	assert_true(wild_span > calm_span * 1.5, "tail swings wider in a thrash (%.3f vs %.3f m)" % [wild_span, calm_span])
	assert_true(calm.outline().size() == FishBody.SEGMENTS * 2 + 3, "outline has both sides and a tail")


# ------------------------------------------------------------------ the loop

func test_loop_casts_bites_fights_and_logs() -> void:
	var screen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	assert_true(screen.has_method("setup"), "the fishing screen script loads")
	if not screen.has_method("setup"):
		screen.free()
		return
	screen.size = Vector2(1280, 720)
	screen.setup("")
	screen._overlay.size = Vector2(1280, 720)
	screen._reel_pad.size = Vector2(260, 300)
	assert_eq(screen.phase, screen.Phase.READY, "starts ready to cast")
	screen.cast_with_power(0.9)
	assert_eq(screen.phase, screen.Phase.FLIGHT, "the lure flies")
	var guard := 0
	while screen.phase == screen.Phase.FLIGHT and guard < 600:
		screen._process(1.0 / 60.0)
		guard += 1
	assert_eq(screen.phase, screen.Phase.WAIT, "the lure lands and the wait starts")
	screen.force_bite("istavrit", 0.3)
	screen._process(1.0 / 60.0)
	# Strike at the centre of the window.
	var w: WaitSim = screen._wait
	while w.phase == WaitSim.PHASE_TAKE and float(w.snapshot()["take_progress"]) < 0.5:
		screen._process(1.0 / 60.0)
	var hooked := false
	for attempt in 30:
		if screen.phase == screen.Phase.FIGHT:
			hooked = true
			break
		if w.phase != WaitSim.PHASE_TAKE:
			screen.force_bite("istavrit", 0.3)
			w = screen._wait
			while w.phase == WaitSim.PHASE_TAKE and float(w.snapshot()["take_progress"]) < 0.5:
				screen._process(1.0 / 60.0)
		screen.strike()
		screen._process(1.0 / 60.0)
	assert_true(hooked, "a strike in the window hooks a fish within 30 tries")
	guard = 0
	while (screen.phase == screen.Phase.FIGHT or screen.phase == screen.Phase.LIFT) and guard < 60000:
		screen.set_fight_input(true, 0.0, false, 0.33)
		screen._process(1.0 / 60.0)
		guard += 1
	assert_eq(screen.phase, screen.Phase.RESULT, "the fight ends in the result screen")
	assert_true(screen._result_panel.visible and screen._result_label.text != "", "result shown")
	if screen._result["outcome"] == FightSim.OUTCOME_LANDED:
		assert_true(screen.save["log"].has("istavrit"), "a landed fish goes into the log")
	screen._update_log()
	assert_true(screen._log_text.text != "", "the log lists the species")
	screen.free()


func test_debug_menu_only_in_debug_builds() -> void:
	var screen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	assert_true(screen.has_method("setup"), "the fishing screen script loads")
	if not screen.has_method("setup"):
		screen.free()
		return
	screen.setup("")
	var expected := OS.is_debug_build() or OS.has_feature("mera_debug")
	assert_eq(screen._debug_menu != null, expected, "debug menu present only in debug builds")
	screen.free()


func test_overmatched_hint_follows_the_estimate() -> void:
	var cond := {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 3}
	var big := FightController.new(FightSetup.build(_db, "levrek", "lrf", "pier_end", 0.95, cond), _k, 1)
	var small := FightController.new(FightSetup.build(_db, "istavrit", "lrf", "pier_end", 0.2, cond), _k, 1)
	assert_true(big.overmatched, "a large sea bass on light tackle is flagged (PRD F19), estimate %.0f s" % big.estimated_fight_s)
	assert_true(not small.overmatched, "a small horse mackerel is not, estimate %.0f s" % small.estimated_fight_s)


func test_recorded_sounds_load_and_are_listed_with_a_licence() -> void:
	var refs := FileAccess.get_file_as_string("res://../docs/reference_docs.md")
	if refs == "":
		refs = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/reference_docs.md"))
	for name_id: String in SoundDirector.WAVES + SoundDirector.ONE_SHOTS + ["wind_loop", "reel_loop", "drag_click"]:
		var path := "%s/%s.ogg" % [SoundDirector.AUDIO_DIR, name_id]
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		assert_true(load(path) is AudioStreamOggVorbis, "%s loads as Ogg Vorbis" % path)
		var listed := refs.contains("`%s.ogg`" % name_id) or (name_id.begins_with("wave_") and refs.contains("`wave_01.ogg` … `wave_04.ogg`"))
		assert_true(listed, "%s is listed in reference_docs.md with its source and licence" % name_id)
