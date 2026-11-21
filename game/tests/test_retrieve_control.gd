extends "res://tests/test_base.gd"
## The player's control of the retrieve: lure depth and reel speed
## (owner request 2026-11-15), and rod pulls that bring the fish in.

var _db: Dictionary
var _k: Dictionary


func _init() -> void:
	_db = DataStore.load_all("res://data")["database"]
	_k = DataStore.load_constants()


func _wait(tackle: String, reel: float, seconds: float, start_s: float = 0.0, start_reel: float = 0.0) -> WaitSim:
	var cond := {"slot": "evening", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(_db, "lufer", tackle, "karakoy_east", 0.5, cond)
	# Only the bluefish swims here, so another species' take does not stop the
	# lure (the tests are about the retrieve, not about who bites).
	var w := WaitSim.new(ctx, _k, _db["species"].filter(func(sp: Dictionary) -> bool: return sp["id"] == "lufer"), 20.0, 4)
	for i in int(start_s * 30.0):
		w.advance(1.0 / 30.0, {"reel": start_reel})
	for i in int(seconds * 30.0):
		w.advance(1.0 / 30.0, {"reel": reel})
	return w


func test_a_sinker_sinks_while_slack_and_the_lure_stays_put() -> void:
	var w := _wait("lrf", 0.0, 6.0)
	assert_near(w.depth_m, 0.3 * 6.0, "depth follows the sink rate (0.3 m/s): %.2f m" % w.depth_m, 0.15)
	assert_near(w.lure_distance_m, 20.0, "not reeling, the lure does not come in", 0.01)


func test_reeling_brings_the_lure_in_and_lifts_a_sinker() -> void:
	var deep := _wait("lrf", 0.0, 8.0)
	var lifted := _wait("lrf", 1.0, 3.0, 8.0, 0.0)
	assert_true(lifted.depth_m < deep.depth_m, "reeling lifts the lure (%.2f m against %.2f m)" % [lifted.depth_m, deep.depth_m])
	assert_near(lifted.lure_distance_m, 20.0 - 3.0 * 1.0, "and brings it in at the reel's speed", 0.1)


func test_a_diving_minnow_dives_deeper_when_reeled_faster() -> void:
	var slow := _wait("spin", 0.25, 5.0)
	var fast := _wait("spin", 1.0, 5.0)
	assert_true(fast.depth_m > slow.depth_m + 0.5, "faster reel, deeper minnow (%.2f m against %.2f m)" % [fast.depth_m, slow.depth_m])
	assert_true(fast.depth_m <= 2.5 + 1e-6, "never deeper than the lure runs")


func test_depth_never_passes_the_water_or_the_lure() -> void:
	var w := _wait("capari", 0.0, 60.0)
	assert_true(w.depth_m <= float(w.snapshot()["water_depth_m"]) * 0.9 + 1e-6, "not into the bottom: %.2f m in %.2f m" % [w.depth_m, w.snapshot()["water_depth_m"]])
	assert_true(w.depth_m > 3.0, "a sabiki keeps sinking while slack")


func test_what_the_player_does_changes_the_bite_rate() -> void:
	# Bluefish are fast and feed from 1 m down: a fast retrieve at depth beats a stopped lure at the top.
	var stopped := _wait("lrf", 0.0, 1.5)
	var working := _wait("lrf", 0.8, 3.0, 5.0, 0.0)
	var a := float(stopped._rates["lufer"]["rate_interest"])
	var b := float(working._rates["lufer"]["rate_interest"])
	assert_true(b > a, "a lure worked at depth draws more interest than one sitting at the top (%.4f against %.4f per s)" % [b, a])


func test_the_original_constant_retrieve_is_unchanged() -> void:
	var cond := {"slot": "evening", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(_db, "istavrit", "lrf", "karakoy_east", 0.5, cond)
	var w := WaitSim.new(ctx, _k, _db["species"], 20.0, 1)
	for i in 30 * 10:
		w.advance(1.0 / 30.0, {})
	assert_true(not w.controlled, "no reel input, the original mode")
	assert_near(w.lure_distance_m, 20.0 - 10.0 * float(_k["WAIT_RETRIEVE_M_PER_S"]), "constant retrieve", 0.1)


func test_pulling_the_rod_brings_the_fish_in_while_the_drag_holds() -> void:
	var cond := {"slot": "evening", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(_db, "istavrit", "lrf", "karakoy_east", 0.2, cond)
	var plain := FightSim.new(ctx, _k, 0.9, 3)
	var pump := FightSim.new(ctx, _k, 0.9, 3)
	for i in 30 * 6:
		plain.step({"reel": 0.0, "rod": 0.0, "drag_kg": 99.0})
		pump.step({"reel": 0.0, "rod": 1.0, "drag_kg": 99.0})
	assert_true(pump.distance_m < plain.distance_m - 1.0, "lifting the rod gains line (%.1f m against %.1f m)" % [pump.distance_m, plain.distance_m])
	var slipping := FightSim.new(ctx, _k, 0.9, 3)
	slipping.step({"reel": 0.0, "rod": 1.0, "drag_kg": 0.01})
	assert_true(slipping.distance_m >= float(ctx["play"]["hook_distance_m"]), "while the drag slips, pulling gains nothing")


func test_the_hooked_fish_carries_the_depth_and_speed_it_was_caught_at() -> void:
	var screen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	screen.cast_with_power(0.8)
	screen._land_lure()
	for i in 120:
		screen._wait.advance(1.0 / 30.0, {"reel": 0.0})   # let a sinker sink for 4 s
	var deep: float = screen._wait.depth_m
	screen._wait.force_take(screen._db["spot"][0]["species"][0]["species_id"])
	for i in 400:
		if screen._wait.phase == WaitSim.PHASE_HOOKED:
			break
		if screen._wait.phase != WaitSim.PHASE_TAKE:
			screen._wait.force_take(screen._db["spot"][0]["species"][0]["species_id"])
		screen._wait.advance(1.0 / 30.0, {"reel": 0.0})
		screen._wait.advance(0.0, {"reel": 0.0, "strike": screen._wait.snapshot()["take_progress"] > 0.4})
	assert_eq(screen._wait.phase, WaitSim.PHASE_HOOKED, "a forced take is hooked sooner or later")
	screen._start_fight(screen._wait.hooked)
	assert_true(deep > 0.5, "the lure sank (%.2f m)" % deep)
	assert_true(absf(float(screen._fight_ctx["play"]["lure_depth_m"]) - screen._wait.depth_m) < 0.6, "the why view sees the real lure depth, not the fixed 3 m")
	screen.free()
