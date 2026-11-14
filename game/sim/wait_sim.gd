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

var _ctx: Dictionary
var _k: Dictionary
var _species: Array
var _rng := RandomNumberGenerator.new()
var _accum := 0.0
var _refresh_left := 0.0
var _rates := {}          # species_id -> {rate_interest, commit, window_s, stages}
var _boost_until := {}    # species_id -> time_s
var _take := {}           # species_id, window_s, elapsed_s


## ctx: a CatchModel context (species is replaced per species); species_records:
## the database's species list; cast_m: where the lure landed.
func _init(ctx: Dictionary, k: Dictionary, species_records: Array, cast_m: float, seed_value: int) -> void:
	_ctx = ctx.duplicate()
	_ctx["play"] = (ctx["play"] as Dictionary).duplicate()
	_k = k
	_rng.seed = seed_value
	lure_distance_m = cast_m
	_species = []
	for entry: Dictionary in ctx["spot"]["species"]:
		for sp: Dictionary in species_records:
			if sp["id"] == entry["species_id"]:
				_species.append(sp)
	_refresh_rates()


func is_over() -> bool:
	return phase == PHASE_HOOKED or phase == PHASE_RETRIEVED


## Frame-rate independent: input {"strike": bool} is applied on the first tick
## of this frame only. speed (1 or more) runs the wait faster (PRD F6); it is
## ignored while a take is on, so the strike window keeps its real length.
func advance(frame_s: float, input: Dictionary, speed: float = 1.0) -> Dictionary:
	var strike: bool = input.get("strike", false)
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
			_log("take_missed", {"species_id": _take["species_id"]})
			_end_take()
		return

	lure_distance_m = maxf(lure_distance_m - float(_k["WAIT_RETRIEVE_M_PER_S"]) * DT, 0.0)
	if lure_distance_m <= float(_k["WAIT_END_M"]):
		phase = PHASE_RETRIEVED
		_log("retrieved", {})
		return
	_refresh_left -= DT
	if _refresh_left <= 0.0:
		_refresh_rates()

	for sp: Dictionary in _species:
		var id: String = sp["id"]
		var r: Dictionary = _rates[id]
		var boost := 1.0 + CatchModel.n(float(sp["schooling"])) if time_s < float(_boost_until.get(id, -1.0)) else 1.0
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
		"take_progress": float(_take.get("elapsed_s", 0.0)) / window if window > 0.0 else 0.0,
		"hooked": hooked,
	}


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
	var window := float(_take["window_s"])
	var half := window * 0.5
	var timing := clampf(1.0 - absf(float(_take["elapsed_s"]) - half) / half, 0.0, 1.0)
	var id: String = _take["species_id"]
	var sp := _species_by_id(id)
	var hk := CatchModel.hook(_k, sp, _ctx["rod"], _ctx["line"], _ctx["lure"], timing)
	var roll := _rng.randf()
	if roll < float(hk["hook"]):
		hooked = {"species_id": id, "u": _rng.randf(), "timing_quality": timing, "hook": hk["hook"], "distance_m": lure_distance_m}
		_log("hooked", {"species_id": id, "timing_quality": timing, "stage_hook": hk, "roll": roll})
		phase = PHASE_HOOKED
		_take = {}
	else:
		_log("hook_failed", {"species_id": id, "timing_quality": timing, "stage_hook": hk, "roll": roll})
		_end_take()


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


func _refresh_rates() -> void:
	_refresh_left = RATE_REFRESH_S
	_ctx["play"]["cast_m"] = lure_distance_m
	for sp: Dictionary in _species:
		var c := _ctx.duplicate()
		c["species"] = sp
		var env := CatchModel.environment(_k, c["spot"], c["position"], c["conditions"])
		var depth := CatchModel.depth_at(c["position"]["depth_profile"], lure_distance_m)
		var pres := CatchModel.presence(_k, sp, c["spot"], c["position"], c["conditions"], env, depth)
		var attr := CatchModel.attraction(_k, sp, c["lure"], c["play"], env, depth)
		var com := CatchModel.commit(_k, sp, c["spot"], c["rod"], c["leader"], env, pres["presence"], attr["attraction"])
		_rates[sp["id"]] = {
			"rate_interest": com["rate_interest"], "commit": com["commit"], "window_s": com["strike_window_s"],
			"stages": {"water_depth_m": depth, "presence": pres, "attraction": attr, "commit": com},
		}


func _species_by_id(id: String) -> Dictionary:
	for sp: Dictionary in _species:
		if sp["id"] == id:
			return sp
	return {}


func _log(event: String, data: Dictionary) -> void:
	var entry := {"time_s": time_s, "event": event, "lure_distance_m": lure_distance_m}
	entry.merge(data)
	events.append(entry)
