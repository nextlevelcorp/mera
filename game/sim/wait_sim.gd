class_name WaitSim
extends RefCounted
## Wait, bite and strike in real time: docs/data_model.md sections 5.3 and 5.4
## (PRD F6, F7). Fixed 30 Hz step, seeded, no nodes. The scene feeds the
## player's strike and draws the signs this returns; it never sees a fish.
##
## While the lure is fished, every species at the spot produces interest
## events as a Poisson process (rate_interest). Each event is a committed take
## with probability c, otherwise a nibble. A take opens the strike window; a
## strike inside it sets the hook with the probability of stage 4, scaled by
## how close to the centre of the window it came. After a take the species'
## rate is raised for a while (a shoal is under the lure). The lure is
## retrieved slowly; when it is back at the shore the cast is over.

const TICK_HZ := 30
const DT := 1.0 / TICK_HZ
const MAX_FRAME_S := 0.25
const RATE_REFRESH_S := 1.0

const PHASE_FISHING := "fishing"
const PHASE_TAKE := "take"
const PHASE_HOOKED := "hooked"
const PHASE_RETRIEVED := "retrieved"

var time_s := 0.0
var lure_distance_m: float
var phase := PHASE_FISHING
var events: Array[Dictionary] = []
## Filled when phase is hooked: species_id, u (size draw), timing_quality,
## hook (probability that was rolled), distance_m.
var hooked := {}
## What came up instead of a fish (2026-11-21): "" for nothing, "weed" (weed
## or rubbish on the hook), "snag_break" (stuck on the bottom, the line went).
var fouled := ""

var _ctx: Dictionary
var _k: Dictionary
var _species: Array
var _rng := RandomNumberGenerator.new()
var _accum := 0.0
var _refresh_left := 0.0
var _rates := {}          # species_id -> {rate_interest, commit, window_s, stages}
var _boost_until := {}    # species_id -> time_s
var _take := {}           # species_id, window_s, elapsed_s
var _jig := 0.0           # 0..1, the player working the lure (phone twitches)
var _reel := 0.0          # 0..1, the player's retrieve effort (controlled mode)

## Controlled retrieve (owner request 2026-11-15): the player decides when the
## lure moves. Not reeling, a sinker sinks (the count-down); reeling brings it
## in at reel effort times the reel's speed and, for a sinker, lifts it; a
## diving lure (sink rate 0) dives deeper the faster it is reeled. The
## retrieve speed and the depth feed stages 2 and 3 of the catch model. Without
## a "reel" input the lure is retrieved at a constant WAIT_RETRIEVE_M_PER_S at the
## play's fixed depth and speed (the original mode, kept for tests and for the
## neighbours' pace).
var controlled := false
## Bait shoals (ShoalField) and where the lure is sideways: x = lure_x0 +
## lure_x_per_m * distance. Without a field nothing changes.
var shoals: ShoalField
var lure_x0 := 0.0
var lure_x_per_m := 0.0
var depth_m := 0.0
var retrieve_ms := 0.0
## From a drifting boat (R23, BoatDrift): the drift speed and how far the
## boat has gone out along its position's depth profile.
var boat := false
var drift_ms := 0.0
var drift_m := 0.0


## ctx: a CatchModel context (species is replaced per species); species_records:
## the database's species list; cast_m: where the lure landed.
func _init(ctx: Dictionary, k: Dictionary, species_records: Array, cast_m: float, seed_value: int) -> void:
	_ctx = ctx.duplicate()
	_ctx["play"] = (ctx["play"] as Dictionary).duplicate()
	_k = k
	_rng.seed = seed_value
	lure_distance_m = cast_m
	boat = BoatDrift.is_boat(ctx["position"])
	if boat:
		drift_ms = BoatDrift.drift_ms(k, float(ctx["conditions"].get("wind_ms", 0.0)))
	if Presentation.is_float(ctx["lure"]):
		depth_m = minf(float(ctx["lure"]["run_depth_max_m"]), CatchModel.depth_at(ctx["position"]["depth_profile"], cast_m) * 0.9)
	_species = []
	for entry: Dictionary in ctx["spot"]["species"]:
		for sp: Dictionary in species_records:
			if sp["id"] == entry["species_id"]:
				_species.append(sp)
	_refresh_rates()


func is_over() -> bool:
	return phase == PHASE_HOOKED or phase == PHASE_RETRIEVED


## Frame-rate independent: input {"strike": bool, "jig": 0..1}; strike is applied on the first tick
## of this frame only. speed (1 or more) runs the wait faster (PRD F6); it is
## ignored while a take is on, so the strike window keeps its real length.
func advance(frame_s: float, input: Dictionary, speed: float = 1.0) -> Dictionary:
	var strike: bool = input.get("strike", false)
	_jig = clampf(float(input.get("jig", 0.0)), 0.0, 1.0)
	controlled = input.has("reel")
	_reel = clampf(float(input.get("reel", 0.0)), 0.0, 1.0)
	var scale := speed if phase == PHASE_FISHING else 1.0
	_accum += minf(maxf(frame_s, 0.0), MAX_FRAME_S) * maxf(scale, 1.0)
	if strike:
		_strike()
	while _accum >= DT and not is_over():
		step()
		_accum -= DT
		if phase == PHASE_TAKE:
			_accum = minf(_accum, DT)
	if is_over():
		_accum = 0.0
	return snapshot()


func step() -> void:
	if is_over():
		return
	time_s += DT
	if phase == PHASE_TAKE:
		_take["elapsed_s"] = float(_take["elapsed_s"]) + DT
		if float(_take["elapsed_s"]) > float(_take["window_s"]):
			_log("take_missed", {"species_id": _take["species_id"], "kind": _take.get("kind", "")})
			_end_take()
		return

	if boat:
		# Straight down from a drifting boat: reeling lifts the lure, and the
		# cast is over when it is back at the surface.
		drift_m += drift_ms * DT
		if controlled:
			retrieve_ms = _reel * float(_ctx["reel"]["retrieve_m_per_s"])
			_update_depth()
			if _reel > 0.3 and depth_m <= 0.05 and time_s > 1.0:
				phase = PHASE_RETRIEVED
				_log("retrieved", {})
				return
	elif controlled:
		retrieve_ms = _reel * float(_ctx["reel"]["retrieve_m_per_s"])
		lure_distance_m = maxf(lure_distance_m - retrieve_ms * DT, 0.0)
		_update_depth()
	elif not Presentation.is_float(_ctx["lure"]):
		lure_distance_m = maxf(lure_distance_m - float(_k["WAIT_RETRIEVE_M_PER_S"]) * DT, 0.0)
	if not boat and lure_distance_m <= float(_k["WAIT_END_M"]):
		phase = PHASE_RETRIEVED
		_log("retrieved", {})
		return
	_refresh_left -= DT
	if _refresh_left <= 0.0:
		_refresh_rates()

	# Not every pull is a fish (owner, 2026-11-21): drifting weed or rubbish
	# anywhere, the bottom when the lure is near it. It looks like a take.
	var near_bottom := not Presentation.is_float(_ctx["lure"]) and depth_m >= water_depth() - float(_k["SNAG_NEAR_BOTTOM_M"])
	if _rng.randf() < float(_k["WEED_RATE_PER_S"]) * DT:
		_open_foul("weed")
		return
	if near_bottom and _rng.randf() < float(_k["SNAG_RATE_PER_S"]) * DT:
		_open_foul("snag")
		return
	for sp: Dictionary in _species:
		var id: String = sp["id"]
		var r: Dictionary = _rates[id]
		var boost := 1.0 + CatchModel.n(float(sp["schooling"])) if time_s < float(_boost_until.get(id, -1.0)) else 1.0
		# Working the lure makes it move like prey: more interest (design fill).
		boost *= 1.0 + float(_k.get("JIG_GAIN", 0.0)) * _jig
		# A lure in a feeding shoal is among fish (design fill).
		boost *= shoal_boost()
		# A drifting boat passes over more fish (R23, design fill).
		if boat:
			boost *= BoatDrift.ground_gain(_k, drift_ms)
		if _rng.randf() < float(r["rate_interest"]) * boost * DT:
			if _rng.randf() < float(r["commit"]):
				_open_take(id)
				return
			_log("nibble", {"species_id": id})


## Debug menu (PRD F15): a committed take by this species, now.
func force_take(species_id: String) -> void:
	if is_over():
		return
	if phase == PHASE_TAKE:
		_end_take()
	if not _rates.has(species_id):
		return
	_open_take(species_id)


func snapshot() -> Dictionary:
	var window := float(_take.get("window_s", 0.0))
	return {
		"time_s": time_s, "phase": phase, "lure_distance_m": lure_distance_m,
		"depth_m": depth_m, "retrieve_ms": retrieve_ms, "controlled": controlled,
		"water_depth_m": water_depth(),
		"take_progress": float(_take.get("elapsed_s", 0.0)) / window if window > 0.0 else 0.0,
		"hooked": hooked, "fouled": fouled, "boat": boat, "drift_ms": drift_ms, "drift_m": drift_m,
	}


func shoal_boost() -> float:
	return shoals.boost_at(lure_x0 + lure_x_per_m * lure_distance_m, lure_distance_m) if shoals else 1.0


## Median wait for any take at the current lure distance, for the "why" view.
func median_wait_s() -> float:
	var total := 0.0
	for id: String in _rates:
		total += float(_rates[id]["rate_interest"]) * float(_rates[id]["commit"])
	return CatchModel.median_wait_s(total)


func _strike() -> void:
	if is_over():
		return
	if phase != PHASE_TAKE:
		_log("strike_empty", {})
		return
	if _take.get("kind", "") != "":
		_strike_foul(String(_take["kind"]))
		return
	var window := float(_take["window_s"])
	var half := window * 0.5
	var timing := clampf(1.0 - absf(float(_take["elapsed_s"]) - half) / half, 0.0, 1.0)
	var id: String = _take["species_id"]
	var sp := _species_by_id(id)
	var hk := CatchModel.hook(_k, sp, _ctx["rod"], _ctx["line"], _ctx["lure"], timing)
	var roll := _rng.randf()
	if roll < float(hk["hook"]):
		hooked = {"species_id": id, "u": _rng.randf(), "timing_quality": timing, "hook": hk["hook"], "distance_m": lure_distance_m,
				"lure_depth_m": float(_ctx["play"]["lure_depth_m"]), "retrieve_speed": float(_ctx["play"]["retrieve_speed"])}
		_log("hooked", {"species_id": id, "timing_quality": timing, "stage_hook": hk, "roll": roll})
		phase = PHASE_HOOKED
		_take = {}
	else:
		_log("hook_failed", {"species_id": id, "timing_quality": timing, "stage_hook": hk, "roll": roll})
		_end_take()


## A pull that is not a fish: weed (or rubbish) or the bottom.
func _open_foul(kind: String) -> void:
	_take = {"species_id": "", "kind": kind, "window_s": float(_k["FOUL_WINDOW_S"]), "elapsed_s": 0.0}
	phase = PHASE_TAKE
	_log("take", {"species_id": "", "kind": kind, "window_s": _take["window_s"]})


## Striking into it: weed comes in and ends the cast; the bottom either lets
## go (fishing on) or the line parts and the lure stays down.
func _strike_foul(kind: String) -> void:
	_take = {}
	if kind == "weed":
		fouled = "weed"
		_log("weed", {})
		phase = PHASE_RETRIEVED
	elif _rng.randf() < float(_k["SNAG_BREAK"]):
		fouled = "snag_break"
		_log("snag_break", {})
		phase = PHASE_RETRIEVED
	else:
		_log("snag_freed", {})
		phase = PHASE_FISHING


## Debug menu: a pull that is not a fish, now ("weed" or "snag").
func force_foul(kind: String) -> void:
	if is_over():
		return
	if phase == PHASE_TAKE:
		_end_take()
	_open_foul(kind)


func _open_take(id: String) -> void:
	var r: Dictionary = _rates[id]
	_take = {"species_id": id, "window_s": float(r["window_s"]), "elapsed_s": 0.0}
	phase = PHASE_TAKE
	_log("take", {"species_id": id, "window_s": r["window_s"], "stages": r["stages"]})


func _end_take() -> void:
	var id: String = _take.get("species_id", "")
	if id != "":
		_boost_until[id] = time_s + float(_k["SHOAL_BOOST_S"])
	_take = {}
	phase = PHASE_FISHING


## Depth follows the lure's kind and how it is reeled; never below the
## surface, never deeper than the lure runs or the water allows.
func _update_depth() -> void:
	var lure: Dictionary = _ctx["lure"]
	var water := water_depth()
	var ceiling := minf(float(lure["run_depth_max_m"]), water * 0.9)
	var sink := float(lure["sink_rate_m_per_s"])
	if boat:
		# The drift drags the line aslant: the lure cannot get as deep (R23).
		ceiling = minf(float(lure["run_depth_max_m"]), water * 0.95) * BoatDrift.line_cos(drift_ms, sink)
	if Presentation.is_float(lure):
		# Under a float the bait hangs at the set depth (or just off the bottom).
		depth_m = float(lure["run_depth_max_m"])
	elif sink > 0.0:
		# A sinker: falls while slack, rises as it is reeled in.
		depth_m += (sink * (1.0 - _reel) - float(_k["RISE_PER_M"]) * retrieve_ms) * DT
	else:
		# A diving lure: heads for a depth that grows with reel speed.
		var lo := float(lure["run_depth_min_m"])
		var target := lo + (float(lure["run_depth_max_m"]) - lo) * _reel if _reel > 0.05 else 0.0
		depth_m = move_toward(depth_m, target, float(_k["DIVE_M_PER_S"]) * DT)
	depth_m = clampf(depth_m, 0.0, maxf(ceiling, 0.0))


func _refresh_rates() -> void:
	_refresh_left = RATE_REFRESH_S
	_ctx["play"]["cast_m"] = lure_distance_m
	if Presentation.is_float(_ctx["lure"]):
		_ctx["play"]["lure_depth_m"] = minf(float(_ctx["lure"]["run_depth_max_m"]), water_depth() * 0.9)
	elif controlled:
		# What the player does is what the model sees (data_model 5.2, 5.3).
		_ctx["play"]["lure_depth_m"] = depth_m
		_ctx["play"]["retrieve_speed"] = 1.0 + 19.0 * _reel
	for sp: Dictionary in _species:
		var c := _ctx.duplicate()
		c["species"] = sp
		var env := CatchModel.environment(_k, c["spot"], c["position"], c["conditions"])
		var depth := water_depth()
		var pres := CatchModel.presence(_k, sp, c["spot"], c["position"], c["conditions"], env, depth)
		var attr := CatchModel.attraction(_k, sp, c["lure"], c["play"], env, depth)
		var com := CatchModel.commit(_k, sp, c["spot"], c["rod"], c["leader"], env, pres["presence"], attr["attraction"])
		_rates[sp["id"]] = {
			"rate_interest": com["rate_interest"], "commit": com["commit"], "window_s": float(com["strike_window_s"]) * Progress.strike_window_factor(_k, _ctx["angler"]),
			"stages": {"water_depth_m": depth, "presence": pres, "attraction": attr, "commit": com},
		}


## The water under the lure: from the shore, at the lure's distance; from a
## boat, under the boat where the drift has taken it (R23).
func water_depth() -> float:
	var x := lure_distance_m + drift_m if boat else lure_distance_m
	return CatchModel.depth_at(_ctx["position"]["depth_profile"], x)


func _species_by_id(id: String) -> Dictionary:
	for sp: Dictionary in _species:
		if sp["id"] == id:
			return sp
	return {}


func _log(event: String, data: Dictionary) -> void:
	var entry := {"time_s": time_s, "event": event, "lure_distance_m": lure_distance_m}
	entry.merge(data)
	events.append(entry)
