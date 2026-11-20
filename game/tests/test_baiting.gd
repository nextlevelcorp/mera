extends "res://tests/test_base.gd"
## Roadmap R20: baiting the hook by hand (owner decision D9).


func _cond() -> Dictionary:
	return {"slot": "dawn", "month": 10, "wind_dir": "NE", "wind_ms": 3}


func _pos() -> String:
	return Db.database()["spot"][0]["positions"][0]["id"]


func _session(rig: String) -> FishingSession:
	var s := FishingSession.new(Db.database(), Db.constants(), rig, _pos(), _cond())
	s.save = SaveGame.fresh()
	Inventory.add(s.save, "shrimp", 20)
	return s


func test_every_kind_of_bait_has_its_own_strokes() -> void:
	for kind: String in Baiting.STROKES:
		var strokes := Baiting.strokes(kind)
		assert_true(strokes.size() >= 2 and strokes.size() <= 3, "%s has two or three strokes" % kind)
		for st: Dictionary in strokes:
			assert_true(TranslationServer.get_translation_object("en").get_message(st["key"]) != "", "%s is translated" % st["key"])
			if st["type"] == "trace":
				for v: Vector2 in st["path"]:
					assert_true(v.x >= 0.0 and v.x <= 1.0 and v.y >= 0.0 and v.y <= Baiting.ASPECT, "%s stays in the close-up" % st["key"])
	var db := Db.database()
	assert_eq(Baiting.kind_of(FightSetup.build(db, "istavrit", "float", _pos(), 0.5, _cond())["lure"]), "shrimp", "the float takes a shrimp")
	assert_eq(Baiting.kind_of(FightSetup.build(db, "istavrit", "float", _pos(), 0.5, _cond(), {"float_bait": "live_istavrit"})["lure"], Db.record("bait", "live_istavrit")), "live", "or a live fish")
	assert_eq(Baiting.kind_of(FightSetup.build(db, "istavrit", "lrf", _pos(), 0.5, _cond())["lure"]), "soft_plastic", "an LRF rig threads a soft plastic")


func test_following_the_path_scores_and_wandering_does_not() -> void:
	var st: Dictionary = Baiting.strokes("soft_plastic")[1]
	var on: Array = []
	var off: Array = []
	for i in 21:
		var t := float(i) / 20.0
		on.append((st["path"][0] as Vector2).lerp(st["path"][1], t))
		off.append((st["path"][0] as Vector2).lerp(st["path"][1], t) + Vector2(0, 0.02 * sin(t * 12.0)))
	var good := Baiting.trace_score(st, on)
	var wobbly := Baiting.trace_score(st, off)
	assert_true(good["finished"] and good["score"] > 0.95, "straight along the body is a good threading (%.2f)" % good["score"])
	assert_true(wobbly["score"] < good["score"] - 0.2, "a wobbly one scores less (%.2f)" % wobbly["score"])
	var half := Baiting.trace_score(st, on.slice(0, 10))
	assert_true(not half["finished"] and half["score"] < 0.6, "stopping half way is not done (%.2f)" % half["score"])
	assert_true(Baiting.starts_trace(st, st["path"][0]), "a trace starts at its ring")
	assert_true(not Baiting.starts_trace(st, Vector2(0.9, 0.5)), "not anywhere")
	var hold: Dictionary = Baiting.strokes("live")[0]
	assert_true(Baiting.hold_score(hold, 1.2, [hold["at"]])["finished"], "a steady hold of the fish is enough")
	assert_true(Baiting.hold_score(hold, 1.2, [(hold["at"] as Vector2) + Vector2(0.06, 0)])["score"] < 0.4, "a thumb off the fish scores little")
	assert_true(is_equal_approx(Baiting.quality([1.0, 0.5, 0.0]), 0.5), "the quality is the mean")
	assert_eq(Baiting.rating_key(0.9), "BAIT_RESULT_GOOD", "good")
	assert_eq(Baiting.rating_key(0.1), "BAIT_RESULT_POOR", "poor")


func test_the_choice_lists_every_rig_with_its_stock() -> void:
	var save := SaveGame.fresh()
	Inventory.add(save, "shrimp", 4)
	Inventory.add(save, "lrf_soft", 2)
	var opts := Baiting.options(Db.database(), save)
	var by_item := {}
	for o: Dictionary in opts:
		by_item[o["item_id"]] = o
	assert_eq(int(by_item["shrimp"]["stock"]), 4, "shrimp from the bag")
	assert_eq(by_item["shrimp"]["rig"], "float", "goes on the float rig")
	assert_eq(int(by_item["lrf_soft"]["stock"]), 2, "soft plastics")
	assert_eq(by_item["lrf_soft"]["rig"], "lrf", "on the light rod")
	assert_eq(int(by_item["live_istavrit"]["stock"]), 0, "no legal horse mackerel yet")
	assert_eq(by_item["live_istavrit"]["kind"], "live", "a live bait")


func test_a_new_rig_must_be_rigged_by_hand_first() -> void:
	var s := _session("lrf")
	assert_true(not s.needs_baiting(s.context("istavrit")), "the rig in hand at arrival is ready")
	s.rig = "spin"
	s.rig_changed()
	assert_true(s.needs_baiting(s.context("istavrit")), "a changed rig needs rigging")
	assert_true(s.bait_hook(s.context("istavrit"), 0.6), "rigged")
	assert_true(not s.needs_baiting(s.context("istavrit")), "and is ready")
	assert_true(is_equal_approx(float(s.context("istavrit")["lure"]["rig_quality"]), 0.6), "the quality goes into the catch context")


func test_a_badly_put_on_bait_draws_fewer_fish() -> void:
	var k := Db.constants()
	var db := Db.database()
	var good := FightSetup.build(db, "istavrit", "float", _pos(), 0.5, _cond())
	var poor := FightSetup.build(db, "istavrit", "float", _pos(), 0.5, _cond(), {"rig_quality": 0.0})
	var env := CatchModel.environment(k, good["spot"], good["position"], _cond())
	var a1 := float(CatchModel.attraction(k, good["species"], good["lure"], good["play"], env, 10.0)["attraction"])
	var a0 := float(CatchModel.attraction(k, poor["species"], poor["lure"], poor["play"], env, 10.0)["attraction"])
	assert_true(is_equal_approx(a0, a1 * float(k["RIG_Q_MIN"])), "a poor baiting keeps RIG_Q_MIN of the draw (%.4f vs %.4f)" % [a0, a1])
	assert_true(not poor["play"].has("rig_quality"), "the setting does not leak into play")


func test_a_badly_put_on_shrimp_flies_off_and_is_stolen_more() -> void:
	var lost := [0, 0]
	var stolen := [0, 0]
	for i in 2:
		var q := 1.0 if i == 0 else 0.0
		var s := _session("float")
		Inventory.add(s.save, "shrimp", 400)
		for n in 200:
			if s.needs_baiting(s.context("istavrit")):
				s.bait_hook(s.context("istavrit"), q)
			if s.cast(s.context("istavrit"), 0.8)["bait_lost"]:
				lost[i] += 1
				continue
			if s.bait_mouthed():
				stolen[i] += 1
	assert_eq(lost[0], 0, "a perfectly baited shrimp never flies off")
	assert_true(lost[1] > 40, "a poorly baited one often does (%d of 200)" % lost[1])
	assert_true(stolen[1] > stolen[0], "and is stolen more (%d vs %d)" % [stolen[1], stolen[0]])


func test_a_well_hooked_live_bait_lasts_longer() -> void:
	var vig := []
	for q: float in [1.0, 0.0]:
		var s := _session("float")
		Inventory.add_fish(s.save, "istavrit", 16.0, 0.05, "2026-11-18")
		s.float_bait = "live_istavrit"
		s.bait_hook(s.context("lufer"), q)
		s.wear_live(20.0)
		vig.append(float(s.live["vigor"]))
	assert_true(vig[0] > vig[1], "well hooked it swims on (%.2f vs %.2f)" % vig)


func test_a_lost_lure_must_be_tied_on_again() -> void:
	var s := _session("lrf")
	var ctx := s.context("istavrit")
	s.record_outcome(FightSim.OUTCOME_LINE_BREAK, ctx, 0.0)
	assert_true(s.needs_baiting(s.context("istavrit")), "a new lure goes on by hand")


func test_the_baiting_screen_runs_the_strokes_by_hand() -> void:
	var p := BaitScreen.new()
	var got := [-1.0]
	p.done.connect(func(q: float) -> void: got[0] = q)
	p.open_rig("minnow", "x")
	assert_true(p.visible, "it opens on the hook")
	for st: Dictionary in Baiting.strokes("minnow"):
		var path: Array = st["path"]
		# The hook's point sits above the thumb: press below the path.
		p.press((path[0] as Vector2) - BaitScreen.HOOK_OFFSET)
		for i in range(1, path.size()):
			for k in 11:
				p.move((path[i - 1] as Vector2).lerp(path[i], float(k) / 10.0) - BaitScreen.HOOK_OFFSET)
		p.release()
	assert_true(not p.visible, "it closes after the last stroke")
	assert_true(got[0] > 0.9, "following every path makes a good baiting (%.2f)" % got[0])
	p.free()


func test_the_screen_asks_for_baiting_before_a_cast() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "float", _cond())
	scr.setup("")
	Inventory.add(Profile.save, "shrimp", 5)
	scr.begin_charge()
	assert_true(scr._bait_screen.visible and scr._bait_screen.stage == "choose", "a bare hook opens the baiting screen on the choice")
	assert_eq(scr.phase, FishingScreen.Phase.READY, "and does not start the cast")
	var lrf := {}
	for o: Dictionary in Baiting.options(Db.database(), Profile.save):
		if o["rig"] == "lrf":
			lrf = o
	scr._on_bait_chosen(lrf)
	assert_eq(scr.rig, "lrf", "choosing a soft plastic switches to the light rod")
	assert_eq(scr._bait_screen.stage, "rig", "then the hook")
	assert_eq(scr._bait_screen.kind, "soft_plastic", "with the soft plastic")
	scr._on_baited(1.0)
	scr.begin_charge()
	assert_eq(scr.phase, FishingScreen.Phase.CHARGE, "baited, the cast charges")
	scr.free()
