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


func test_every_kind_of_bait_has_its_own_steps() -> void:
	for kind: String in Baiting.STEPS:
		var steps := Baiting.steps(kind)
		assert_true(steps.size() >= 2 and steps.size() <= 3, "%s has two or three steps" % kind)
		for st: Array in steps:
			assert_true(TranslationServer.get_translation_object("en").get_message(st[0]) != "", "%s is translated" % st[0])
	var db := Db.database()
	assert_eq(Baiting.kind_of(FightSetup.build(db, "istavrit", "float", _pos(), 0.5, _cond())["lure"]), "shrimp", "the float takes a shrimp")
	assert_eq(Baiting.kind_of(FightSetup.build(db, "istavrit", "float", _pos(), 0.5, _cond(), {"float_bait": "live_istavrit"})["lure"], Db.record("bait", "live_istavrit")), "live", "or a live fish")
	assert_eq(Baiting.kind_of(FightSetup.build(db, "istavrit", "lrf", _pos(), 0.5, _cond())["lure"]), "soft_plastic", "an LRF rig threads a soft plastic")


func test_the_needle_sweeps_and_the_taps_score() -> void:
	assert_eq(Baiting.needle(0.0, 1.0), 0.0, "starts at the left")
	assert_true(is_equal_approx(Baiting.needle(0.5, 1.0), 0.5), "half way")
	assert_true(is_equal_approx(Baiting.needle(1.5, 1.0), 0.5), "and back")
	assert_eq(Baiting.accuracy(0.5, 0.5, 0.2), 1.0, "a centre tap is perfect")
	assert_eq(Baiting.accuracy(0.8, 0.5, 0.2), 0.0, "outside the zone scores nothing")
	assert_true(is_equal_approx(Baiting.quality([1.0, 0.5, 0.0]), 0.5), "the quality is the mean")
	assert_eq(Baiting.rating_key(0.9), "BAIT_RESULT_GOOD", "good")
	assert_eq(Baiting.rating_key(0.1), "BAIT_RESULT_POOR", "poor")


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


func test_the_baiting_panel_runs_the_steps() -> void:
	var p := BaitPanel.new()
	var got := [-1.0]
	p.done.connect(func(q: float) -> void: got[0] = q)
	p.start("minnow", "x")
	assert_true(p.visible, "it opens")
	for i in Baiting.steps("minnow").size():
		# Wait until the needle is at the zone's centre, then tap.
		var speed := float(Baiting.steps("minnow")[i][2])
		p._process(Baiting.zone_centre(i) / speed)
		p.press()
	assert_true(not p.visible, "it closes after the last step")
	assert_true(got[0] > 0.95, "centre taps make a good baiting (%.2f)" % got[0])
	p.free()


func test_the_screen_asks_for_baiting_before_a_cast() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "float", _cond())
	scr.setup("")
	Inventory.add(Profile.save, "shrimp", 5)
	scr.begin_charge()
	assert_true(scr._bait_panel.visible, "a bare hook opens the baiting screen")
	assert_eq(scr.phase, FishingScreen.Phase.READY, "and does not start the cast")
	scr._on_baited(1.0)
	scr.begin_charge()
	assert_eq(scr.phase, FishingScreen.Phase.CHARGE, "baited, the cast charges")
	scr.free()
