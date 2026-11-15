extends "res://tests/test_base.gd"
## Real-time fight (docs/data_model.md 5.5) against the closed-form estimate of
## CatchModel.fight and the PRD F8 rules. Fixtures are illustrative design fills.

const Helper := preload("res://tests/test_catch_model.gd")
const SEEDS := 200

var _h
var _k: Dictionary
var _examples := {}


func _setup() -> void:
	_h = Helper.new()
	_h._setup()
	_k = _h._k
	for example: Dictionary in _h._examples():
		_examples[example["name"]] = example


func _steady(drag: float) -> Callable:
	return func(_state: Dictionary) -> Dictionary: return {"reel": 1.0, "rod": 0.0, "drag_kg": drag}


func _idle(drag: float) -> Callable:
	return func(_state: Dictionary) -> Dictionary: return {"reel": 0.0, "rod": 0.0, "drag_kg": drag}


## Runs SEEDS fights; returns counts per outcome, mean landed time, max time, estimate.
func _survey(name: String, policy_maker: Callable) -> Dictionary:
	var example: Dictionary = _examples[name]
	var ctx: Dictionary = _h._ctx(example)
	var est: Dictionary = CatchModel.resolve(ctx, _k)
	var counts := {}
	var landed_time := 0.0
	var max_time := 0.0
	var caps := 0
	for i in SEEDS:
		var fight := FightSim.new(ctx, _k, est["hook"]["hook"], i + 1)
		var result := fight.run(policy_maker.call(float(example["play"]["drag_kg"])))
		counts[result["outcome"]] = int(counts.get(result["outcome"], 0)) + 1
		max_time = maxf(max_time, result["time_s"])
		if result["cap_applied"]:
			caps += 1
		if result["outcome"] == FightSim.OUTCOME_LANDED:
			landed_time += result["time_s"]
	var landed: int = counts.get(FightSim.OUTCOME_LANDED, 0)
	return {"counts": counts, "landed": landed, "mean_landed_s": landed_time / landed if landed > 0 else -1.0, "max_s": max_time, "caps": caps, "est": est}


func test_same_seed_same_fight() -> void:
	_setup()
	var ctx: Dictionary = _h._ctx(_examples["C2"])
	var a := FightSim.new(ctx, _k, 0.64, 42).run(_steady(1.2))
	var b := FightSim.new(ctx, _k, 0.64, 42).run(_steady(1.2))
	assert_eq(a, b, "same seed and inputs give the same fight")
	var times := {}
	for s in 20:
		times[FightSim.new(ctx, _k, 0.64, s + 1).run(_steady(1.2))["time_s"]] = true
	assert_true(times.size() > 5, "different seeds give different fights")


func test_small_fish_on_matched_tackle_is_always_landed() -> void:
	_setup()
	var r := _survey("A", _steady)
	assert_eq(r["landed"], SEEDS, "example A: every fight is landed, got %s" % str(r["counts"]))
	var est: float = r["est"]["fight"]["t_fight"]
	assert_true(absf(r["mean_landed_s"] - est) <= 0.25 * est, "example A: mean fight %s s is within 25%% of the estimate %s s" % [str(r["mean_landed_s"]), str(est)])


func test_fight_length_tracks_the_closed_form_estimate() -> void:
	_setup()
	for name in ["B", "C2"]:
		var r := _survey(name, _steady)
		var est: float = r["est"]["fight"]["t_fight"]
		assert_true(absf(r["mean_landed_s"] - est) <= 0.25 * est, "example %s: mean landed fight %s s is within 25%% of the estimate %s s" % [name, str(r["mean_landed_s"]), str(est)])


func _careful(drag: float) -> Callable:
	# Reels, but waits while the hanging fish kicks.
	return func(state: Dictionary) -> Dictionary: return {"reel": 0.0 if state["kicking"] else 1.0, "rod": 0.0, "drag_kg": drag}


## The landing is the player's: the closed-form estimate sits between a
## careless landing (reeling through the kicks) and a careful one.
func test_landing_rate_brackets_the_closed_form_estimate() -> void:
	_setup()
	for name in ["B", "C2"]:
		var careless := _survey(name, _steady)
		var careful := _survey(name, _careful)
		var est_p: float = careless["est"]["chain"]["p_land_given_take"] / careless["est"]["hook"]["hook"]
		var lo := float(careless["landed"]) / SEEDS
		var hi := float(careful["landed"]) / SEEDS
		assert_true(hi > lo or (name == "B" and hi >= lo), "example %s: waiting out the kicks lands more fish (%s against %s)" % [name, str(hi), str(lo)])
		assert_true(lo <= est_p + 0.1 and hi >= est_p - 0.1, "example %s: estimate %s lies between careless %s and careful %s" % [name, str(est_p), str(lo), str(hi)])


func test_a_landing_needs_the_player_to_reel() -> void:
	_setup()
	var ctx: Dictionary = _h._ctx(_examples["A"])
	var fight := FightSim.new(ctx, _k, 0.9, 3)
	var state := fight.run(func(s: Dictionary) -> Dictionary: return {"reel": 0.0 if s["in_landing"] and float(s["time_s"]) < 60.0 else 1.0, "rod": 0.0, "drag_kg": 1.0})
	assert_true(float(state["time_s"]) >= 60.0 or state["outcome"] != FightSim.OUTCOME_LANDED, "a fish left hanging is not landed by itself")
	var f2 := FightSim.new(ctx, _k, 0.9, 3)
	var seen := 0.0
	while not f2.is_over():
		var s := f2.step({"reel": 1.0, "rod": 0.0, "drag_kg": 1.0})
		assert_true(float(s["lift"]) >= seen, "the lift only goes up")
		seen = float(s["lift"])


func test_runs_go_sideways_and_side_strain_holds_them() -> void:
	_setup()
	var ctx: Dictionary = _h._ctx(_examples["C2"])
	var free := 0.0
	var held := 0.0
	var e_free := 0.0
	var e_held := 0.0
	for seed_value in range(1, 41):
		var a := FightSim.new(ctx, _k, 0.64, seed_value)
		var b := FightSim.new(ctx, _k, 0.64, seed_value)
		for i in 90:
			var sa := a.step({"reel": 0.3, "rod": 1.0, "drag_kg": 1.2})
			var sb := b.step({"reel": 0.3, "rod": 1.0, "drag_kg": 1.2, "steer": -float(b.heading)})
			assert_true(absf(float(sa["side_m"])) <= float(_k["SIDE_MAX_SHARE"]) * float(sa["distance_m"]) + 0.001, "sideways stays inside the fan")
			if a.is_over() or b.is_over():
				break
		free += absf(a.side_m)
		held += absf(b.side_m)
		e_free += a.energy
		e_held += b.energy
	assert_true(free > 0.5, "a running fish moves sideways (%.2f m over 40 fights)" % free)
	assert_true(held < free * 0.6, "side strain holds it (%.2f against %.2f)" % [held, free])
	assert_true(e_held < e_free, "and tires it faster")


func test_a_hard_pull_on_a_jump_can_throw_the_hook() -> void:
	_setup()
	var ctx: Dictionary = _h._ctx(_examples["C2"])
	var jumps := 0
	var thrown_hard := 0
	var thrown_eased := 0
	for seed_value in range(1, 201):
		for hard in [true, false]:
			var f := FightSim.new(ctx, _k, 0.5, seed_value)
			var s := f.snapshot()
			while not f.is_over():
				s = f.step({"reel": 1.0, "rod": 1.0 if (hard or not s["jumping"]) else 0.0, "drag_kg": 1.2})
			if hard:
				for e: Dictionary in f.events:
					if e["event"] == "jump":
						jumps += 1
			if s["thrown_on_jump"]:
				if hard:
					thrown_hard += 1
				else:
					thrown_eased += 1
	assert_true(jumps > 10, "fish jump near the surface (%d jumps)" % jumps)
	assert_true(thrown_hard > 0, "pulling through the jumps throws some hooks (%d)" % thrown_hard)
	assert_eq(thrown_eased, 0, "easing the rod on a jump never throws the hook")


func test_drag_above_line_strength_breaks_on_the_first_run() -> void:
	_setup()
	var r := _survey("C", _steady)
	assert_eq(r["counts"].get(FightSim.OUTCOME_LINE_BREAK, 0), SEEDS, "example C: the line always breaks, got %s" % str(r["counts"]))
	assert_true(r["max_s"] <= 2.0 * FightSim.DT, "example C: it breaks on the first tick")


func test_teeth_cut_only_when_the_species_has_them() -> void:
	_setup()
	assert_eq(_survey("A", _steady)["counts"].get(FightSim.OUTCOME_LEADER_CUT, 0), 0, "teeth 1 never cuts")
	assert_true(_survey("C2", _steady)["counts"].get(FightSim.OUTCOME_LEADER_CUT, 0) > SEEDS / 5, "a bluefish often cuts a fluorocarbon leader")


func test_slack_line_loses_fish() -> void:
	_setup()
	var tight := _survey("A", _steady)
	var slack := _survey("A", _idle)
	assert_true(slack["counts"].get(FightSim.OUTCOME_HOOK_PULLED, 0) > SEEDS / 4, "not reeling loses many fish to hook pull-outs, got %s" % str(slack["counts"]))
	assert_eq(tight["counts"].get(FightSim.OUTCOME_HOOK_PULLED, 0), 0, "a tight line never pulls the hook in example A")


func test_no_fight_exceeds_the_cap() -> void:
	_setup()
	for name in ["A", "B", "C2"]:
		for maker in [_steady, _idle]:
			var r := _survey(name, maker)
			assert_true(r["max_s"] <= float(_k["FIGHT_CAP_S"]) + FightSim.DT, "example %s: longest fight %s s is within the 90 s cap" % [name, str(r["max_s"])])


func test_cap_resolves_an_overmatched_fight() -> void:
	_setup()
	var example: Dictionary = (_examples["C2"] as Dictionary).duplicate(true)
	example["play"]["fish_length_cm"] = 80.0
	example["play"]["drag_kg"] = 0.7
	var ctx: Dictionary = _h._ctx(example)
	var est: Dictionary = CatchModel.resolve(ctx, _k)
	assert_true(est["fight"]["cap_applied"], "an 80 cm bluefish on light tackle is over the cap in the estimate")
	var capped := 0
	var finished := 0
	for i in 50:
		var fight := FightSim.new(ctx, _k, est["hook"]["hook"], i + 1)
		var result := fight.run(_steady(0.7))
		assert_true(result["time_s"] <= 90.0 + FightSim.DT, "capped at 90 s")
		finished += 1
		if result["cap_applied"]:
			capped += 1
			assert_true(result["outcome"] in [FightSim.OUTCOME_LANDED, FightSim.OUTCOME_HOOK_PULLED], "the cap ends in landed or hook pulled")
			if result["outcome"] == FightSim.OUTCOME_LANDED:
				assert_true(float(result["distance_m"]) <= float(_k["CAP_LAND_DISTANCE_M"]), "the cap lands only a fish near the shore (%.1f m)" % result["distance_m"])
	assert_eq(finished, 50, "every fight ends")
	assert_true(capped > 0, "the 90 s rule fires for this fight")


func test_state_invariants_every_tick() -> void:
	_setup()
	var ctx: Dictionary = _h._ctx(_examples["C2"])
	var fight := FightSim.new(ctx, _k, 0.64, 7)
	var last_energy := 1.0
	var ticks := 0
	while not fight.is_over():
		var s := fight.step({"reel": 1.0, "rod": 0.5, "drag_kg": 99.0})
		ticks += 1
		assert_true(s["energy_share"] <= last_energy + 1e-9, "energy never rises")
		last_energy = s["energy_share"]
		assert_true(s["distance_m"] >= 0.0, "distance is not negative")
		if not fight.is_over():
			assert_true(s["tension_kg"] <= fight.drag_max + 1e-9, "tension is limited by the reel's maximum drag even when the input asks for more")
	assert_true(ticks > 0 and fight.is_over(), "the fight ends")
	assert_true(not fight.events.is_empty(), "the fight logs its events")
	var after := fight.step({"reel": 1.0})
	assert_eq(after["outcome"], fight.outcome, "stepping a finished fight changes nothing")
