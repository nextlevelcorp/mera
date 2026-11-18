extends "res://tests/test_base.gd"
## Roadmap R12: float fishing with natural bait.


func _cond() -> Dictionary:
	return {"slot": "dawn", "month": 10, "wind_dir": "NE", "wind_ms": 3}


func _pos() -> String:
	return Db.database()["spot"][0]["positions"][0]["id"]


func _ctx(species_id: String, tackle: String, overrides: Dictionary = {}) -> Dictionary:
	return FightSetup.build(Db.database(), species_id, tackle, _pos(), 0.5, _cond(), overrides)


func test_the_float_rig_hangs_bait_at_the_set_depth() -> void:
	var ctx := _ctx("istavrit", "float")
	assert_true(Presentation.is_float(ctx["lure"]), "the float rig fishes a bait under a float")
	assert_eq(ctx["lure"]["id"], "shrimp", "shrimp is the bait")
	assert_eq(float(ctx["play"]["lure_depth_m"]), 3.0, "at the float's default depth")
	assert_eq(float(ctx["play"]["retrieve_speed"]), 1.0, "and it barely moves")
	assert_eq(float(_ctx("istavrit", "float", {"float_depth_m": 5.5})["lure"]["run_depth_max_m"]), 5.5, "the angler sets the depth")
	assert_eq(float(_ctx("istavrit", "float", {"float_depth_m": 40.0})["lure"]["run_depth_max_m"]), 8.0, "within the float's limits")
	assert_true(not ctx["play"].has("float_depth_m"), "the depth setting does not leak into play")
	assert_true(not Presentation.is_float(_ctx("istavrit", "lrf")["lure"]), "a lure rig is not a float")


func test_scent_finds_the_fish_and_lures_keep_their_numbers() -> void:
	var k := Db.constants()
	var ctx := _ctx("istavrit", "lrf")
	var env := CatchModel.environment(k, ctx["spot"], ctx["position"], _cond())
	var lure: Dictionary = ctx["lure"]
	var a := CatchModel.attraction(k, ctx["species"], lure, ctx["play"], env, 10.0)
	var vis := float(env["visibility"])
	var visual := 0.5 * CatchModel.n(float(lure["flash"])) + 0.5 * CatchModel.n(float(lure["action"]))
	var expected := float(k["DETECT_BASE"]) + (1.0 - float(k["DETECT_BASE"])) * (vis + (1.0 - vis) * visual)
	assert_true(is_equal_approx(float(a["F"]), expected), "a lure is still found by sight as before")
	var fctx := _ctx("istavrit", "float")
	var fa := CatchModel.attraction(k, fctx["species"], fctx["lure"], fctx["play"], env, 10.0)
	assert_true(float(fa["F"]) > float(a["F"]), "a scented bait is found more easily than a lure in this light")


func test_shrimp_suits_horse_mackerel_more_than_the_hunters() -> void:
	var k := Db.constants()
	var out := {}
	for sp: String in ["istavrit", "lufer", "palamut"]:
		var c := _ctx(sp, "float")
		var env := CatchModel.environment(k, c["spot"], c["position"], _cond())
		out[sp] = float(CatchModel.attraction(k, c["species"], c["lure"], c["play"], env, 10.0)["attraction"])
	assert_true(out["istavrit"] > out["lufer"] and out["istavrit"] > out["palamut"], "shrimp under a float is a horse mackerel bait: %s" % str(out))


func test_the_float_stays_where_it_landed_until_reeled() -> void:
	var k := Db.constants()
	var ctx := _ctx("istavrit", "float")
	var w := WaitSim.new(ctx, k, Db.database()["species"], 20.0, 3)
	for i in 60:
		w.step()
	assert_true(is_equal_approx(w.lure_distance_m, 20.0) or w.is_over(), "no retrieve without reeling")
	var water := CatchModel.depth_at(ctx["position"]["depth_profile"], 20.0)
	assert_true(is_equal_approx(w.depth_m, minf(3.0, water * 0.9)), "the bait hangs at the float depth (or above the bottom)")
	var r := WaitSim.new(ctx, k, Db.database()["species"], 20.0, 3)
	r.advance(1.0, {"reel": 1.0})
	assert_true(r.lure_distance_m < 20.0 or r.is_over(), "reeling brings the float in")
	assert_true(r.is_over() or is_equal_approx(r.depth_m, minf(3.0, CatchModel.depth_at(ctx["position"]["depth_profile"], r.lure_distance_m) * 0.9)), "at the same depth")


func test_bites_come_on_the_float_in_a_reasonable_time() -> void:
	var k := Db.constants()
	var ctx := _ctx("istavrit", "float")
	var wait_s := WaitSim.new(ctx, k, Db.database()["species"], 20.0, 1).median_wait_s()
	assert_true(wait_s > 5.0 and wait_s < 300.0, "median wait for a take at dawn: %.0f s" % wait_s)


func test_a_bait_is_used_on_every_cast() -> void:
	var save := SaveGame.fresh()
	Inventory.add(save, "shrimp", 3)
	Inventory.add(save, "lrf_soft", 3)
	var s := FishingSession.new(Db.database(), Db.constants(), "float", _pos(), _cond())
	s.save = save
	s.cast(s.context("istavrit"), 0.8)
	assert_eq(Inventory.count(save, "shrimp"), 2, "one shrimp per cast")
	s.rig = "lrf"
	s.cast(s.context("istavrit"), 0.8)
	assert_eq(Inventory.count(save, "lrf_soft"), 3, "a lure is not used up by casting")
	s.rig = "float"
	s.float_depth_m = 6.0
	assert_eq(float(s.context("istavrit")["lure"]["run_depth_max_m"]), 6.0, "the session keeps the depth")


func test_shrimp_is_sold_and_given_to_a_new_angler() -> void:
	var c := Economy.load_catalog(Db.database())
	assert_true(c["ok"], "the shop loads: %s" % str(c["errors"]))
	assert_true(Economy.lure_price(c["catalog"], "shrimp") > 0, "shrimp is sold")
	var save := SaveGame.fresh()
	Economy.give_starting_stock(save, c["catalog"])
	assert_true(Inventory.count(save, "shrimp") > 0, "and some comes with the welcome stock")


func test_the_fishing_screen_sets_the_float_depth() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "float", _cond())
	scr.setup("")
	assert_true(scr.is_float(), "the float rig is on")
	var before := scr.float_depth()
	scr.change_float_depth(0.5)
	assert_eq(scr.float_depth(), before + 0.5, "deeper by half a metre")
	for i in 30:
		scr.change_float_depth(0.5)
	assert_eq(scr.float_depth(), 8.0, "no deeper than the float allows")
	assert_true(scr._ui.float_row != null, "the rig panel has the depth row")
	scr.free()


func test_a_take_pulls_the_float_under() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "float", _cond())
	scr.setup("")
	Inventory.add(Profile.save, "shrimp", 5)
	scr.force_bite("istavrit")
	for i in 20:
		scr._process(1.0 / 60.0)
	assert_eq(scr._wait_state.get("phase", ""), WaitSim.PHASE_TAKE, "a take is on")
	assert_true(scr.float_dip > 10.0, "the float is pulled under (%.1f px)" % scr.float_dip)
	scr.free()


func test_live_bait_is_a_legal_horse_mackerel_from_the_bag() -> void:
	var db := Db.database()
	var bait := Db.record("bait", "live_istavrit")
	var save := SaveGame.fresh()
	Inventory.add_fish(save, "istavrit", 10.0, 0.01, "2026-11-18")   # undersize: goes back, not on the hook
	assert_eq(Presentation.bait_stock(save, bait, db["species"]), 0, "an undersize fish is no bait")
	Inventory.add_fish(save, "istavrit", 18.0, 0.06, "2026-11-18")
	Inventory.add_fish(save, "istavrit", 14.0, 0.03, "2026-11-18")
	Inventory.add_fish(save, "lufer", 25.0, 0.2, "2026-11-18")
	assert_eq(Presentation.bait_stock(save, bait, db["species"]), 2, "two legal horse mackerel")
	var s := FishingSession.new(db, Db.constants(), "float", _pos(), _cond())
	s.save = save
	s.float_bait = "live_istavrit"
	var ctx := s.context("lufer")
	assert_eq(ctx["lure"]["id"], "live_istavrit", "the rig fishes the live bait")
	assert_eq(s.stock(ctx), 2, "the session counts it")
	s.cast(ctx, 0.8)
	assert_eq(s.stock(ctx), 1, "a cast uses one")
	var left: Array = []
	for it: Dictionary in Inventory.items(save):
		if it["id"] == "fish:istavrit":
			left.append(float(it["meta"]["length_cm"]))
	left.sort()
	assert_eq(left, [10.0, 18.0], "the smallest legal one went on the hook")
	assert_eq(Inventory.count(save, "fish:lufer"), 1, "other fish stay")


func test_live_bait_suits_the_hunters() -> void:
	var k := Db.constants()
	var live := {}
	var shrimp := {}
	for sp: String in ["istavrit", "lufer", "palamut"]:
		for pair: Array in [[live, "live_istavrit"], [shrimp, "shrimp"]]:
			var c := _ctx(sp, "float", {"float_bait": pair[1]})
			var env := CatchModel.environment(k, c["spot"], c["position"], _cond())
			var a := CatchModel.attraction(k, c["species"], c["lure"], c["play"], env, 10.0)
			var h := CatchModel.hook(k, c["species"], c["rod"], c["line"], c["lure"], 0.8)
			(pair[0] as Dictionary)[sp] = float(a["attraction"]) * float(h["hook"])
	assert_true(live["lufer"] > shrimp["lufer"] and live["palamut"] > shrimp["palamut"], "live bait catches more hunters than shrimp: %s %s" % [str(live), str(shrimp)])
	assert_true(shrimp["istavrit"] > live["istavrit"], "shrimp stays the horse mackerel bait")


func test_the_rig_panel_cycles_the_bait() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "float", _cond())
	scr.setup("")
	assert_eq(scr._ctx["lure"]["id"], "shrimp", "shrimp first")
	scr.cycle_bait()
	assert_eq(scr._ctx["lure"]["id"], "live_istavrit", "then live bait")
	assert_eq(scr.lure_stock(), 0, "with no legal horse mackerel in a fresh bag")
	scr.cycle_bait()
	assert_eq(scr._ctx["lure"]["id"], "shrimp", "and back")
	scr.free()
