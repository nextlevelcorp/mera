class_name FightSim
extends RefCounted
## Real-time fight, docs/data_model.md section 5.5. Fixed time step, seeded,
## no nodes: the scene feeds player input each tick and draws the returned
## state. The same seed and the same inputs always give the same fight.
##
## Player input per tick (two thumbs, PRD F8):
##   reel     0..1  left thumb: retrieve effort
##   rod      0..1  right thumb: pulling the rod against the fish
##   drag_kg  0..reel.drag_max_kg  right thumb: drag setting

const TICK_HZ := 30
const DT := 1.0 / TICK_HZ

enum FishState { RUN, REST, THRASH }

const OUTCOME_NONE := ""
const OUTCOME_LANDED := "landed"
const OUTCOME_LINE_BREAK := "line_break"
const OUTCOME_LEADER_CUT := "leader_cut"
const OUTCOME_HOOK_PULLED := "hook_pulled"
const OUTCOME_LOST_AT_EDGE := "lost_at_edge"

# Fixed for the fight.
var weight_kg: float
var f_max: float
var e0: float
var b_eff: float
var hook_hold: float
var landing_q: float
var cut_rate: float
var run_speed: float
var angler_pull_max: float
var retrieve_m_per_s: float
var drag_max: float
var smoothness_n: float
var thrash_n: float
var stamina_n: float

# Changing state.
var time_s := 0.0
var energy: float
var distance_m: float
var fish_state: int = FishState.RUN
var state_left_s := 0.0
var tension := 0.0
var strain_s := 0.0
var landing_s := 0.0
var in_landing := false
var outcome := OUTCOME_NONE
var cap_applied := false
var events: Array[Dictionary] = []

var _k: Dictionary
var _rng := RandomNumberGenerator.new()
var _run_started := false


## ctx: the same context CatchModel.resolve takes. hook_hold: the h of stage 4.
func _init(ctx: Dictionary, k: Dictionary, hook_hold_value: float, seed_value: int) -> void:
	_k = k
	_rng.seed = seed_value
	var sp: Dictionary = ctx["species"]
	var est := CatchModel.fight(k, sp, ctx["position"], ctx["reel"], ctx["line"], ctx["leader"], ctx["angler"], ctx["play"])
	var env := CatchModel.environment(k, ctx["spot"], ctx["position"], ctx["conditions"])
	weight_kg = est["W_kg"]
	f_max = est["Fmax_kgf"]
	e0 = est["E0"]
	b_eff = est["Beff"]
	cut_rate = est["cut_rate_per_s"]
	landing_q = CatchModel.landing(k, ctx["position"], env, weight_kg, b_eff)["landing_q"]
	hook_hold = hook_hold_value
	run_speed = float(k["RUN_SPEED_BASE"]) + float(k["RUN_SPEED_RANGE"]) * CatchModel.n(float(sp["speed"]))
	angler_pull_max = float(k["ANGLER_PULL_BASE"]) + float(k["ANGLER_PULL_RANGE"]) * CatchModel.n(float(ctx["rod"]["power"]))
	retrieve_m_per_s = float(ctx["reel"]["retrieve_m_per_s"])
	drag_max = float(ctx["reel"]["drag_max_kg"])
	smoothness_n = CatchModel.n(float(ctx["reel"]["smoothness"]))
	thrash_n = CatchModel.n(float(sp["surface_thrash"]))
	stamina_n = CatchModel.n(float(sp["stamina"]))
	energy = e0
	distance_m = float(ctx["play"]["hook_distance_m"])
	_enter(FishState.RUN)


func is_over() -> bool:
	return outcome != OUTCOME_NONE


## Advances one tick and returns the state to draw.
func step(input: Dictionary) -> Dictionary:
	if is_over():
		return snapshot()
	var reel: float = clampf(float(input.get("reel", 0.0)), 0.0, 1.0)
	var rod: float = clampf(float(input.get("rod", 0.0)), 0.0, 1.0)
	var drag: float = clampf(float(input.get("drag_kg", 0.0)), 0.0, drag_max)
	time_s += DT

	if in_landing:
		_step_landing()
		return snapshot()

	# Fish behaviour.
	state_left_s -= DT
	if state_left_s <= 0.0:
		_next_state()
	var energy_share := clampf(energy / e0, 0.0, 1.0)
	var effort: float = float(_k["EFFORT"][_state_name()])
	var fish_pull := f_max * effort * sqrt(energy_share)

	# Tension: fish and angler pull against each other, the drag is the limit.
	var angler_pull := angler_pull_max * (0.5 * reel + 0.5 * rod)
	var demand := fish_pull + angler_pull
	var slipping := demand > drag
	tension = minf(demand, drag)

	# A run that starts against a slipping drag overshoots the setting.
	if _run_started:
		_run_started = false
		if slipping:
			var spike := drag * (1.0 + float(_k["SPIKE"]) * (1.0 - smoothness_n))
			if spike > b_eff:
				tension = spike
				return _finish(OUTCOME_LINE_BREAK)

	# Line break.
	if tension > b_eff:
		return _finish(OUTCOME_LINE_BREAK)
	if tension > float(_k["STRAIN_SHARE"]) * b_eff:
		strain_s += DT
		if strain_s > float(_k["STRAIN_LIMIT_S"]):
			return _finish(OUTCOME_LINE_BREAK)
	else:
		strain_s = 0.0

	# Teeth on the leader.
	if cut_rate > 0.0 and _rng.randf() < cut_rate * DT:
		return _finish(OUTCOME_LEADER_CUT)

	# Slack line lets the hook fall out: the fish is not running and the
	# angler is not keeping pressure on it.
	if fish_state != FishState.RUN and angler_pull < float(_k["SLACK_SHARE"]) * angler_pull_max:
		if _rng.randf() < float(_k["SLACK_HAZARD"]) * (1.0 - hook_hold) * DT:
			return _finish(OUTCOME_HOOK_PULLED)

	# Line out or line in.
	if slipping:
		distance_m += run_speed * effort * sqrt(energy_share) * (demand - drag) / demand * DT
	elif reel > 0.0 and drag > 0.0:
		# Line comes in whenever the drag holds; the harder the fish pulls
		# against the drag setting, the slower it comes.
		distance_m -= reel * retrieve_m_per_s * (1.0 - fish_pull / drag) * DT
	distance_m = maxf(distance_m, 0.0)

	# Tiring.
	energy = maxf(energy - (tension + float(_k["REST_DRAIN"]) * f_max) * DT, 0.0)

	if energy <= float(_k["LAND_ENERGY"]) * e0 and distance_m <= float(_k["LAND_DISTANCE_M"]):
		in_landing = true
		landing_s = 0.0

	# The 90 s rule (PRD F8): a game rule, not realism. Only a tired fish that
	# is already close to the shore counts as landed (owner, 2026-11-13); a
	# fish still far out pulls the hook.
	if time_s >= float(_k["FIGHT_CAP_S"]) and not is_over():
		cap_applied = true
		var tired := energy <= float(_k["CAP_LAND_ENERGY"]) * e0
		var close := distance_m <= float(_k["CAP_LAND_DISTANCE_M"])
		return _finish(OUTCOME_LANDED if tired and close else OUTCOME_HOOK_PULLED)
	return snapshot()


func snapshot() -> Dictionary:
	return {
		"time_s": time_s, "tension_kg": tension, "line_strength_kg": b_eff,
		"energy_share": energy / e0, "distance_m": distance_m,
		"fish_state": _state_name(), "in_landing": in_landing,
		"strain_s": strain_s, "outcome": outcome, "cap_applied": cap_applied,
	}


## Runs a whole fight with a policy: Callable(state: Dictionary) -> input Dictionary.
func run(policy: Callable) -> Dictionary:
	var state := snapshot()
	while not is_over():
		state = step(policy.call(state))
	return state


func _step_landing() -> void:
	landing_s += DT
	tension = minf(weight_kg, b_eff)
	if landing_s >= float(_k["LAND_PHASE"]):
		_finish(OUTCOME_LANDED if _rng.randf() < landing_q else OUTCOME_LOST_AT_EDGE)


func _finish(result: String) -> Dictionary:
	outcome = result
	events.append({"time_s": time_s, "event": result, "tension_kg": tension, "energy_share": energy / e0, "distance_m": distance_m})
	return snapshot()


func _next_state() -> void:
	match fish_state:
		FishState.RUN:
			_enter(FishState.REST)
		_:
			var near_surface := distance_m <= float(_k["THRASH_DISTANCE_M"])
			if fish_state == FishState.REST and near_surface and _rng.randf() < thrash_n:
				_enter(FishState.THRASH)
			else:
				_enter(FishState.RUN)


func _enter(state: int) -> void:
	fish_state = state
	var span: Array = _k["STATE_SECONDS"][_state_name()]
	var base := _rng.randf_range(float(span[0]), float(span[1]))
	# Fish with more stamina run longer and rest less.
	if state == FishState.RUN:
		base *= 0.75 + 0.5 * stamina_n
	elif state == FishState.REST:
		base *= 1.25 - 0.5 * stamina_n
	state_left_s = base
	_run_started = state == FishState.RUN
	events.append({"time_s": time_s, "event": "state:%s" % _state_name(), "energy_share": energy / e0 if e0 > 0.0 else 0.0, "distance_m": distance_m})


func _state_name() -> String:
	match fish_state:
		FishState.RUN:
			return "run"
		FishState.REST:
			return "rest"
		_:
			return "thrash"
