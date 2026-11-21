extends "res://tests/test_base.gd"
## Owner's play notes (2026-11-21): pulls that are not fish, a fish that only
## takes the bait, and several fish on a sabiki.


func _cond() -> Dictionary:
	return {"slot": "dawn", "month": 10, "wind_dir": "NE", "wind_ms": 3}


func _pos() -> String:
	return Db.database()["spot"][0]["positions"][0]["id"]


func _ctx(rig: String, species: String = "istavrit") -> Dictionary:
	return FightSetup.build(Db.database(), species, rig, _pos(), 0.5, _cond())


func test_weed_comes_up_and_ends_the_cast() -> void:
	var w := WaitSim.new(_ctx("lrf"), Db.constants(), Db.database()["species"], 20.0, 3)
	w.force_foul("weed")
	assert_eq(w.phase, WaitSim.PHASE_TAKE, "it looks like a take")
	w.advance(0.05, {"strike": true})
	assert_eq(w.fouled, "weed", "but weed came up")
	assert_true(w.is_over(), "and the cast is over")
	assert_true(w.hooked.is_empty(), "no fish")


func test_a_bottom_snag_either_lets_go_or_parts_the_line() -> void:
	var seen := {}
	for seed_value in 40:
		var w := WaitSim.new(_ctx("lrf"), Db.constants(), Db.database()["species"], 20.0, seed_value)
		w.force_foul("snag")
		w.advance(0.05, {"strike": true})
		seen[w.fouled if w.fouled != "" else w.phase] = true
	assert_true(seen.has("snag_break") and seen.has(WaitSim.PHASE_FISHING), "both happen over 40 casts: %s" % str(seen.keys()))
	var s := FishingSession.new(Db.database(), Db.constants(), "lrf", _pos(), _cond())
	s.lose_to_snag(s.context("istavrit"))
	assert_true(s.needs_baiting(s.context("istavrit")), "a lure left on the bottom must be replaced")
	assert_eq((s.trip["lost"] as Array).size(), 1, "and the trip records it")


func test_fouls_happen_now_and_then_while_fishing() -> void:
	var k := Db.constants()
	var fouls := 0
	for seed_value in 30:
		var w := WaitSim.new(_ctx("capari"), k, Db.database()["species"], 25.0, seed_value)
		w.controlled = true
		for i in 600:   # 60 s with the sabiki down near the bottom
			w.advance(0.1, {"reel": 0.0})
			if w.phase == WaitSim.PHASE_TAKE:
				for e: Dictionary in w.events:
					if e["event"] == "take" and String(e.get("kind", "")) != "":
						fouls += 1
				break
	assert_true(fouls > 0 and fouls < 30, "some casts, not all, meet weed or the bottom (%d of 30)" % fouls)


func test_a_sabiki_brings_up_a_varied_number_of_fish() -> void:
	var s := FishingSession.new(Db.database(), Db.constants(), "capari", _pos(), _cond())
	var ctx := s.context("istavrit")
	var counts := {}
	for i in 200:
		var x := s.sabiki_extras(ctx)
		counts[x.size()] = true
		assert_true(x.size() <= int(Db.constants()["SABIKI_HOOKS"]) - 1, "never more fish than hooks")
		for f: Dictionary in x:
			assert_eq(f["species_id"], "istavrit", "the same shoal")
	assert_true(counts.has(0) and counts.size() >= 3, "sometimes none, sometimes one, sometimes more: %s" % str(counts.keys()))
	var lrf := FishingSession.new(Db.database(), Db.constants(), "lrf", _pos(), _cond())
	assert_true(lrf.sabiki_extras(lrf.context("istavrit")).is_empty(), "one hook, one fish on other rigs")


func test_a_landed_sabiki_fish_puts_its_companions_in_the_trip() -> void:
	var s := FishingSession.new(Db.database(), Db.constants(), "capari", _pos(), _cond())
	var total := 0
	for i in 20:
		var ctx := s.context("istavrit")
		ctx["play"]["fish_length_cm"] = 15.0
		total += 1 + s.record_outcome(FightSim.OUTCOME_LANDED, ctx, 0.04).size()
	assert_eq((s.trip["catches"] as Array).size(), total, "every fish on the hooks is in the catch")
	assert_true(total > 20, "more fish than fights (%d from 20)" % total)


func test_only_a_soft_plastic_can_be_torn() -> void:
	var s := FishingSession.new(Db.database(), Db.constants(), "lrf", _pos(), _cond())
	var torn := 0
	for i in 300:
		torn += 1 if s.lure_torn(s.context("istavrit")) else 0
	assert_true(torn > 10 and torn < 90, "a soft plastic is sometimes torn (%d of 300)" % torn)
	var spin := FishingSession.new(Db.database(), Db.constants(), "spin", _pos(), _cond())
	for i in 50:
		assert_true(not spin.lure_torn(spin.context("istavrit")), "a hard lure is not")
