class_name FishingSession
extends RefCounted
## One visit to a standing position, from arriving to leaving (roadmap R2):
## the rig and the conditions it is fished under, the cast, the wait and the
## fight it starts, and the record of what happened (the FishingResult of
## Game). Pure: no nodes, no clock, seeded. The fishing screen owns the
## phases, which follow the view's timing (lure flight, the lift), and asks
## this for every rule-bearing step.

var db: Dictionary
var k: Dictionary
var rig: String
var position_id: String
var conditions: Dictionary          ## shared with the caller, who may change it in place
var clarity_override := -1.0        ## debug menu: replaces the spot's clarity when above 0
var shoals: ShoalField
var seed_counter := 1
var trip := Game.empty_result()
## The player's save, for the skills (Progress); empty keeps the base angler.
var save := {}
## The float rig's depth (R12); the float's default until the angler changes it.
var float_depth_m := -1.0
## The float rig's bait (baits.json id).
var float_bait := FightSetup.FLOAT_BAIT
## The live bait on the hook between casts (R12): the fish's length_cm,
## weight_kg, caught_at and its vigor 1..0. Empty when none is out.
var live := {}
## Baiting (R20): a shrimp on the hook, the rig whose lure was last rigged by
## hand, and the quality 0..1 of that baiting. A lure rig starts rigged.
var shrimp_on := false
var rigged := ""
var rig_quality := 1.0
var _rng := RandomNumberGenerator.new()


func _init(database: Dictionary, constants: Dictionary, rig_id: String, position: String, session_conditions: Dictionary, shoal_field: ShoalField = null) -> void:
	db = database
	k = constants
	rig = rig_id
	rigged = rig_id
	_rng.seed = 4241
	position_id = position
	conditions = session_conditions
	shoals = shoal_field


## The CatchModel context for a species on the current rig and position.
func context(species_id: String, overrides: Dictionary = {}) -> Dictionary:
	var o := overrides
	if rig == "float":
		o = overrides.duplicate()
		if float_depth_m > 0.0 and not o.has("float_depth_m"):
			o["float_depth_m"] = float_depth_m
		if not o.has("float_bait"):
			o["float_bait"] = float_bait
		if not live.is_empty():
			o["float_vigor"] = float(live["vigor"])
	if not o.has("rig_quality") and rig_quality < 1.0:
		if o == overrides:
			o = overrides.duplicate()
		o["rig_quality"] = rig_quality
	var ctx := FightSetup.build(db, species_id, rig, position_id, 0.5, conditions, o)
	if not save.is_empty():
		ctx["angler"] = Progress.angler(ctx["angler"], save, k)
	if clarity_override > 0.0:
		var spot: Dictionary = (ctx["spot"] as Dictionary).duplicate()
		spot["typical_clarity"] = clarity_override
		ctx["spot"] = spot
	return ctx


## A cast at this power: CatchModel.cast, never shorter than the retrieve's end.
func cast(ctx: Dictionary, power: float) -> Dictionary:
	trip["casts"] = int(trip["casts"]) + 1
	seed_counter += 1
	var c := CatchModel.cast(k, ctx["rod"], ctx["lure"], ctx["angler"], ctx["position"], conditions, power)
	c["cast_m"] = maxf(float(c["cast_m"]), float(k["WAIT_END_M"]) + 2.0)
	# A natural bait that was badly put on may fly off the hook (R20).
	c["bait_lost"] = false
	if Presentation.is_float(ctx["lure"]) and _bait_out() and _rng.randf() < float(k["BAIT_FLYOFF"]) * (1.0 - rig_quality):
		_lose_bait()
		c["bait_lost"] = true
	return c


## True when the hook has to be baited (or the lure rigged) before a cast:
## the rig changed, or the natural bait is gone.
func needs_baiting(ctx: Dictionary) -> bool:
	if Presentation.is_float(ctx["lure"]):
		return not _bait_out()
	return rigged != rig


## The baiting is done with this quality: a shrimp or a live fish goes on the
## hook (from the bag), or the lure is rigged. False when there is none to use.
func bait_hook(ctx: Dictionary, quality: float) -> bool:
	if Presentation.is_float(ctx["lure"]):
		var bait := _bait(ctx["lure"]["id"])
		if bait.has("from_species"):
			_hook_live(bait)
			if live.is_empty():
				return false
		else:
			if save.is_empty() or not Presentation.use_bait(save, bait, db["species"]):
				return false
			shrimp_on = true
	rigged = rig
	rig_quality = clampf(quality, 0.0, 1.0)
	return true


## A fish mouthed the natural bait without being hooked: a shrimp may be
## stolen, more likely when it was badly put on.
func bait_mouthed() -> bool:
	if shrimp_on and _rng.randf() < float(k["BAIT_STEAL"]) * (1.2 - rig_quality):
		shrimp_on = false
		return true
	return false


## The rig or the bait changed: the hook needs baiting again (a live fish that
## was out goes back in the bag).
func rig_changed() -> void:
	release_live()
	shrimp_on = false
	rig_quality = 1.0


func _bait_out() -> bool:
	return shrimp_on or not live.is_empty()


func _lose_bait() -> void:
	shrimp_on = false
	live = {}


## The wait for the lure that landed cast_m out, aim_rad to the side.
func start_wait(ctx: Dictionary, cast_m: float, aim_rad: float) -> WaitSim:
	var wait := WaitSim.new(ctx, k, db["species"], cast_m, seed_counter * 7919)
	wait.shoals = shoals
	wait.lure_x0 = -0.3
	wait.lure_x_per_m = tan(aim_rad)
	return wait


## The fight context for a hooked fish (WaitSim.hooked); forced_u >= 0 sets its size draw.
func fight_context(hooked: Dictionary, forced_u: float = -1.0) -> Dictionary:
	var u: float = forced_u if forced_u >= 0.0 else float(hooked["u"])
	var d: float = hooked["distance_m"]
	var overrides := {"cast_m": d, "hook_distance_m": d, "timing_quality": hooked["timing_quality"]}
	# What the player did with the lure is what the "why" view explains.
	for key: String in ["lure_depth_m", "retrieve_speed"]:
		if hooked.has(key):
			overrides[key] = hooked[key]
	var ctx := context(hooked["species_id"], overrides)
	ctx["play"]["fish_length_cm"] = FightController.draw_length_cm(ctx["species"], u)
	return ctx


func start_fight(fight_ctx: Dictionary) -> FightController:
	return FightController.new(fight_ctx, k, seed_counter)


## Writes the end of a fight into the trip. Returns the extra fish a sabiki
## brought up with the one that was fought (also written into the trip).
func record_outcome(outcome: String, fight_ctx: Dictionary, weight_kg: float) -> Array[Dictionary]:
	var species_id: String = fight_ctx["species"]["id"]
	(trip["events"] as Array).append({"type": outcome, "species_id": species_id})
	var extra: Array[Dictionary] = []
	if outcome == FightSim.OUTCOME_LANDED:
		(trip["catches"] as Array).append({"species_id": species_id, "length_cm": float(fight_ctx["play"]["fish_length_cm"]), "weight_kg": weight_kg, "kept": true})
		extra = sabiki_extras(fight_ctx)
		for e: Dictionary in extra:
			(trip["catches"] as Array).append({"species_id": e["species_id"], "length_cm": e["length_cm"], "weight_kg": e["weight_kg"], "kept": true})
	elif outcome in [FightSim.OUTCOME_LINE_BREAK, FightSim.OUTCOME_LEADER_CUT]:
		(trip["lost"] as Array).append({"item_id": fight_ctx["lure"]["id"], "reason": outcome})
		rigged = ""   # the lure went with the line: tie on a new one by hand
	return extra


## How many of the last n fish in the trip are under their legal size.
func undersize_count(n: int) -> int:
	var count := 0
	for c: Dictionary in _last_catches(n):
		if c.get("kept", false) and _undersize(c):
			count += 1
	return count


## Puts the undersize ones among the last n fish back: they leave the trip's
## bucket (kept false) and never reach the bag.
func release_undersize(n: int) -> int:
	var count := 0
	for c: Dictionary in _last_catches(n):
		if c.get("kept", false) and _undersize(c):
			c["kept"] = false
			count += 1
	return count


func _last_catches(n: int) -> Array:
	var catches: Array = trip["catches"]
	return catches.slice(maxi(catches.size() - n, 0))


func _undersize(c: Dictionary) -> bool:
	for sp: Dictionary in db["species"]:
		if sp["id"] == c["species_id"]:
			var rule: Dictionary = sp.get("regulation", {})
			return rule.has("min_length_cm") and float(c["length_cm"]) < float(rule["min_length_cm"])
	return false


## A sabiki has several hooks (SABIKI_HOOKS); a schooling fish often brings
## company: each other hook holds one more of the same species with chance
## SABIKI_EXTRA_P * n(schooling), and some hooks stay empty. Sizes are drawn
## like any fish. Nothing for other rigs.
func sabiki_extras(fight_ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if String(fight_ctx["lure"].get("type", "")) != "sabiki":
		return out
	var sp: Dictionary = fight_ctx["species"]
	var p := float(k["SABIKI_EXTRA_P"]) * CatchModel.n(float(sp["schooling"]))
	for i in int(k["SABIKI_HOOKS"]) - 1:
		if _rng.randf() < p:
			var length := FightController.draw_length_cm(sp, _rng.randf())
			out.append({"species_id": sp["id"], "length_cm": length, "weight_kg": float(sp["lw_a"]) * pow(length, float(sp["lw_b"])) / 1000.0})
	return out


## The fish that missed the hook tore a soft plastic's tail off (it is spent).
func lure_torn(ctx: Dictionary) -> bool:
	return String(ctx["lure"].get("type", "")) == "soft_plastic" and _rng.randf() < float(k["SOFT_TEAR"])


## The line parted on the bottom: a lure is gone and must be tied on again; a
## float rig loses its bait.
func lose_to_snag(ctx: Dictionary) -> void:
	(trip["lost"] as Array).append({"item_id": ctx["lure"]["id"], "reason": "snag"})
	if Presentation.is_float(ctx["lure"]):
		_lose_bait()
	else:
		rigged = ""


func add_time(seconds: float) -> void:
	trip["time_s"] = float(trip["time_s"]) + maxf(seconds, 0.0)


## The FishingResult so far (a copy).
func result() -> Dictionary:
	return trip.duplicate(true)


## How many casts are left with the rig's bait or lure.
func stock(ctx: Dictionary) -> int:
	if Presentation.is_float(ctx["lure"]):
		var bait := _bait(ctx["lure"]["id"])
		return Presentation.bait_stock(save, bait, db["species"]) + (1 if _bait_out() else 0)
	return Inventory.count(save, ctx["lure"]["id"])


func _bait(id: String) -> Dictionary:
	for b: Dictionary in db.get("bait", []):
		if b["id"] == id:
			return b
	return {}


## Puts the smallest legal fish of the bait's species on the hook, unless one
## is already out.
func _hook_live(bait: Dictionary) -> void:
	if not live.is_empty():
		return
	var fish := Presentation.live_bait_fish(save, bait, _species(bait["from_species"]))
	if fish.is_empty():
		return
	var it: Dictionary = Inventory.items(save)[fish[0]]
	live = {"length_cm": float(it["meta"]["length_cm"]), "weight_kg": float(it["meta"]["weight_kg"]), "caught_at": String(it["meta"].get("caught_at", "")), "species_id": String(bait["from_species"]), "vigor": 1.0}
	Inventory.items(save).remove_at(fish[0])


## The end of a cast with the live bait still on: it tires with the cast, with
## the seconds it waited and, if a fish only mouthed it, more. Returns false
## when it is spent (and gone).
func wear_live(wait_s: float, bitten: bool = false) -> bool:
	if live.is_empty():
		return true
	var wear := float(k["LIVE_WEAR_PER_CAST"]) + float(k["LIVE_WEAR_PER_S"]) * maxf(wait_s, 0.0) + (float(k["LIVE_BITTEN_WEAR"]) if bitten else 0.0)
	wear *= 1.5 - 0.5 * rig_quality   # a well-hooked live fish lasts longer (R20)
	live["vigor"] = float(live["vigor"]) - wear
	if float(live["vigor"]) <= 0.0:
		live = {}
		return false
	return true


## A hooked fish took the bait: it is gone (a live fish or a shrimp).
func lose_live() -> void:
	live = {}
	shrimp_on = false


## Leaving: a live bait still alive goes back into the bag.
func release_live() -> void:
	if live.is_empty() or save.is_empty():
		return
	Inventory.add_fish(save, String(live["species_id"]), float(live["length_cm"]), float(live["weight_kg"]), String(live["caught_at"]))
	live = {}


func _species(id: String) -> Dictionary:
	for s: Dictionary in db["species"]:
		if s["id"] == id:
			return s
	return {}
