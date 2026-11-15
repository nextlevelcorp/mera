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
##   steer    -1..1 optional: side strain, the rod pulled left or right
##
## Added 2026-11-15 (owner: complete the fight): a running fish also runs
## sideways, and side strain against its heading slows that and tires it
## faster; a thrashing fish near the surface may jump, and a hard rod pull
## during a jump can throw the hook (ease the rod, keep reeling); the landing
## is the player's: reel the fish up while it hangs calm, wait while it kicks.

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
var side_m := 0.0          ## sideways from the line of the cast, + is right
var heading := 1.0         ## -1 or 1: which way the fish runs sideways
var jumping := false
var jump_left_s := 0.0
var thrown_on_jump := false
var lift := 0.0            ## landing: 0 at the water, 1 over the rail
var kicking := false       ## landing: the fish is kicking on the line
var _kick_left_s := 0.0
var events: Array[Dictionary] = []

var _k: Dictionary
var _rng := RandomNumberGenerator.new()
var _rng_b := RandomNumberGenerator.new()   # sideways runs, jumps, landing kicks
var _run_started := false


## ctx: the same context CatchModel.resolve takes. hook_hold: the h of stage 4.
func _init(ctx: Dictionary, k: Dictionary, hook_hold_value: float, seed_value: int) -> void:
	_k = k
	_rng.seed = seed_value
	_rng_b.seed = seed_value * 31 + 17
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
	var steer: float = clampf(float(input.get("steer", 0.0)), -1.0, 1.0)
	time_s += DT

	if in_landing:
		_step_landing(reel)
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

	# A jump: a tight rod on a fish in the air lets it throw the hook.
	if jumping:
		jump_left_s -= DT
		# The first JUMP_GRACE_S are the player's time to react.
		if rod > 0.5 and jump_left_s < float(_k["JUMP_S"]) - float(_k["JUMP_GRACE_S"]) and _rng_b.randf() < float(_k["JUMP_HAZARD"]) * (1.0 - hook_hold) * DT:
			thrown_on_jump = true
			return _finish(OUTCOME_HOOK_PULLED)
		if jump_left_s <= 0.0:
			jumping = false

	# Sideways: a running fish goes its own way; side strain against its
	# heading (rod pulled the other way) slows it and tires it faster.
	var strain := absf(steer) * rod if steer * heading < 0.0 else 0.0
	if fish_state == FishState.RUN:
		side_m += heading * run_speed * effort * sqrt(energy_share) * float(_k["LATERAL_SHARE"]) * (1.0 - float(_k["SIDE_STRAIN_TURN"]) * strain) * DT
	else:
		side_m = move_toward(side_m, 0.0, float(_k["SIDE_RETURN_M_PER_S"]) * (0.5 * reel + 0.5 * rod) * DT)
	var side_max := float(_k["SIDE_MAX_SHARE"]) * distance_m
	side_m = clampf(side_m, -side_max, side_max)

	# Line out or line in.
	if slipping:
		distance_m += run_speed * effort * sqrt(energy_share) * (demand - drag) / demand * DT
	elif (reel > 0.0 or rod > 0.0) and drag > 0.0:
		# Line comes in whenever the drag holds; the harder the fish pulls
		# against the drag setting, the slower it comes. Lifting the rod
		# (pumping) brings the fish in too, at LIFT_M_PER_S (owner feedback
		# 2026-11-15: pulling felt useless); it only works while the drag holds.
		var held := 1.0 - fish_pull / drag
		distance_m -= (reel * retrieve_m_per_s + rod * float(_k["LIFT_M_PER_S"])) * held * DT
	distance_m = maxf(distance_m, 0.0)

	# Tiring.
	energy = maxf(energy - (tension * (1.0 + float(_k["SIDE_STRAIN_DRAIN"]) * strain) + float(_k["REST_DRAIN"]) * f_max) * DT, 0.0)

	if energy <= float(_k["LAND_ENERGY"]) * e0 and distance_m <= float(_k["LAND_DISTANCE_M"]):
		in_landing = true
		landing_s = 0.0
		jumping = false
		_kick_left_s = _rng_b.randf_range(1.0, 2.2)

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
		"side_m": side_m, "heading": heading, "jumping": jumping, "jump_left_s": jump_left_s,
		"thrown_on_jump": thrown_on_jump, "lift": lift, "kicking": kicking,
	}


## Runs a whole fight with a policy: Callable(state: Dictionary) -> input Dictionary.
func run(policy: Callable) -> Dictionary:
	var state := snapshot()
	while not is_over():
		state = step(policy.call(state))
	return state


## The landing is the player's (owner, 2026-11-15): the fish hangs on the line
## and is reeled up to the rail. It kicks now and then; reeling through a kick
## can shake it off, more easily the worse the landing chance (landing_q) of
## this fish at this place. Waiting costs a little too: a fish left hanging
## may work the hook loose.
func _step_landing(reel: float) -> void:
	landing_s += DT
	tension = minf(weight_kg, b_eff)
	_kick_left_s -= DT
	if _kick_left_s <= 0.0:
		kicking = not kicking
		_kick_left_s = float(_k["LAND_KICK_S"]) if kicking else _rng_b.randf_range(1.0, 2.2)
	var risk := 1.0 - landing_q
	var hazard := float(_k["LAND_HANG_HAZARD"])
	if kicking and reel > 0.3:
		hazard += float(_k["LAND_KICK_HAZARD"])
	if _rng_b.randf() < hazard * risk * DT:
		_finish(OUTCOME_LOST_AT_EDGE)
		return
	lift = minf(lift + reel * DT / float(_k["LAND_PHASE"]), 1.0)
	if lift >= 1.0:
		_finish(OUTCOME_LOST_AT_EDGE if _rng.randf() < risk * float(_k["LAND_BASE_SHARE"]) else OUTCOME_LANDED)


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
				if _rng_b.randf() < thrash_n * float(_k["JUMP_SHARE"]):
					jumping = true
					jump_left_s = float(_k["JUMP_S"])
					events.append({"time_s": time_s, "event": "jump", "distance_m": distance_m})
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
	if state == FishState.RUN:
		heading = 1.0 if _rng_b.randf() < 0.5 else -1.0
	events.append({"time_s": time_s, "event": "state:%s" % _state_name(), "energy_share": energy / e0 if e0 > 0.0 else 0.0, "distance_m": distance_m})


func _state_name() -> String:
	match fish_state:
		FishState.RUN:
			return "run"
		FishState.REST:
			return "rest"
		_:
			return "thrash"
