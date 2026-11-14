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


func test_landing_rate_tracks_the_closed_form_estimate() -> void:
	_setup()
	for name in ["B", "C2"]:
		var r := _survey(name, _steady)
		# The estimate's chain includes the hook stage; a fight starts after it.
		var est_p: float = r["est"]["chain"]["p_land_given_take"] / r["est"]["hook"]["hook"]
		var rate := float(r["landed"]) / SEEDS
		assert_true(absf(rate - est_p) <= 0.1, "example %s: landing rate %s is within 0.1 of the estimate %s (%s)" % [name, str(rate), str(est_p), str(r["counts"])])


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
