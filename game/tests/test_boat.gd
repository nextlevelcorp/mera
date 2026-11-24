extends "res://tests/test_base.gd"
## Roadmap R23: a rented boat that drifts (owner decisions D7 and 2026-11-23).

const Unlocks := preload("res://tests/test_unlocks.gd")


func _cond(wind: float) -> Dictionary:
	return {"slot": "dawn", "month": 10, "wind_dir": "NE", "wind_ms": wind}


func _wait(wind: float, reel_after_s: float = -1.0, seconds: float = 60.0) -> WaitSim:
	var ctx := FightSetup.build(Db.database(), "istavrit", "capari", "galata_bridge_boat", 0.5, _cond(wind))
	var w := WaitSim.new(ctx, Db.constants(), [], float(Db.constants()["BOAT_DROP_M"]), 3)
	for i in int(seconds * 10):
		w.advance(0.1, {"reel": 1.0 if reel_after_s >= 0.0 and i * 0.1 >= reel_after_s else 0.0})
		if w.is_over():
			break
	return w


func test_the_boat_drifts_faster_in_more_wind_up_to_a_limit() -> void:
	var k := Db.constants()
	assert_eq(BoatDrift.drift_ms(k, 0.0), 0.0, "no wind, no drift")
	assert_true(BoatDrift.drift_ms(k, 6.0) > BoatDrift.drift_ms(k, 3.0), "more wind, more drift")
	assert_eq(BoatDrift.drift_ms(k, 40.0), float(k["BOAT_DRIFT_MAX_MS"]), "capped")


func test_the_water_under_the_boat_changes_as_it_drifts() -> void:
	var w := _wait(8.0, -1.0, 120.0)
	assert_true(w.drift_m > 30.0, "two minutes in a fresh wind take the boat out (%.0f m)" % w.drift_m)
	var calm := _wait(0.0, -1.0, 120.0)
	assert_true(w.water_depth() > calm.water_depth(), "and over deeper water (%.0f m against %.0f m)" % [w.water_depth(), calm.water_depth()])


func test_a_fast_drift_keeps_a_light_lure_off_the_bottom() -> void:
	assert_eq(BoatDrift.line_cos(0.0, 1.0), 1.0, "straight down in a calm")
	assert_true(BoatDrift.line_cos(0.5, 0.3) < 0.6, "a light lure in a fast drift hangs well off the bottom")
	var slow := _wait(1.0, -1.0, 40.0)
	var fast := _wait(15.0, -1.0, 40.0)
	assert_true(fast.depth_m / fast.water_depth() < slow.depth_m / slow.water_depth(), "the sabiki gets less far down in a strong drift")


func test_reeling_up_brings_the_lure_to_the_surface_and_ends_the_drop() -> void:
	var w := _wait(3.0, 20.0, 200.0)
	assert_eq(w.phase, WaitSim.PHASE_RETRIEVED, "reeled to the top, the drop is over")
	assert_true(w.depth_m <= 0.05, "at the surface")


func test_drifting_passes_more_fish() -> void:
	var k := Db.constants()
	assert_true(BoatDrift.ground_gain(k, 0.3) > BoatDrift.ground_gain(k, 0.0), "a drifting boat covers more ground")


func test_a_boat_is_rented_with_the_rank_and_money_and_never_where_a_visit_starts() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("galata_bridge", "", "capari", _cond(3.0))
	scr.setup("")
	assert_true(not scr.in_boat(), "a visit starts on the shore")
	scr.toggle_boat()
	assert_true(not scr.in_boat(), "a newcomer cannot rent one (it opens at the third rank)")
	var ranked: Dictionary = Unlocks.new()._with_badges(11)
	scr.save.merge(ranked, true)
	scr.save["money"] = 500
	scr.toggle_boat()
	assert_true(scr.in_boat(), "with the rank, the boat is rented")
	assert_eq(Economy.money(scr.save), 500 - int(scr.boat_position()["rent_tl"]), "and paid for")
	assert_eq(FightSim.lift_height(Db.constants(), scr._ctx["position"]), float(Db.constants()["LIFT_HEIGHT_BOAT_M"]), "a fish comes in over the gunwale")
	scr.toggle_boat()
	assert_true(not scr.in_boat(), "back to the shore")
	scr.free()


func test_the_debug_menu_boards_the_boat_for_free() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("galata_bridge", "", "lrf", _cond(3.0))
	scr.setup("")
	var money := Economy.money(scr.save)
	scr.debug_boat()
	assert_true(scr.in_boat(), "aboard without rank")
	assert_eq(Economy.money(scr.save), money, "and without rent")
	scr.debug_boat()
	assert_true(not scr.in_boat(), "and back")
	scr.free()
