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


func _init(database: Dictionary, constants: Dictionary, rig_id: String, position: String, session_conditions: Dictionary, shoal_field: ShoalField = null) -> void:
	db = database
	k = constants
	rig = rig_id
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
	# A bait is used up on every cast (a lure is only lost to a break).
	if Presentation.is_float(ctx["lure"]) and not save.is_empty():
		var bait := _bait(ctx["lure"]["id"])
		if bait.has("from_species"):
			_hook_live(bait)   # a live fish stays on the hook between casts
		else:
			Presentation.use_bait(save, bait, db["species"])
	var c := CatchModel.cast(k, ctx["rod"], ctx["lure"], ctx["angler"], ctx["position"], conditions, power)
	c["cast_m"] = maxf(float(c["cast_m"]), float(k["WAIT_END_M"]) + 2.0)
	return c


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


## Writes the end of a fight into the trip.
func record_outcome(outcome: String, fight_ctx: Dictionary, weight_kg: float) -> void:
	var species_id: String = fight_ctx["species"]["id"]
	(trip["events"] as Array).append({"type": outcome, "species_id": species_id})
	if outcome == FightSim.OUTCOME_LANDED:
		(trip["catches"] as Array).append({"species_id": species_id, "length_cm": float(fight_ctx["play"]["fish_length_cm"]), "weight_kg": weight_kg, "kept": true})
	elif outcome in [FightSim.OUTCOME_LINE_BREAK, FightSim.OUTCOME_LEADER_CUT]:
		(trip["lost"] as Array).append({"item_id": fight_ctx["lure"]["id"], "reason": outcome})


func add_time(seconds: float) -> void:
	trip["time_s"] = float(trip["time_s"]) + maxf(seconds, 0.0)


## The FishingResult so far (a copy).
func result() -> Dictionary:
	return trip.duplicate(true)


## How many casts are left with the rig's bait or lure.
func stock(ctx: Dictionary) -> int:
	if Presentation.is_float(ctx["lure"]):
		var bait := _bait(ctx["lure"]["id"])
		return Presentation.bait_stock(save, bait, db["species"]) + (1 if bait.has("from_species") and not live.is_empty() else 0)
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
	live["vigor"] = float(live["vigor"]) - wear
	if float(live["vigor"]) <= 0.0:
		live = {}
		return false
	return true


## A hooked fish took the bait: it is gone.
func lose_live() -> void:
	live = {}


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
