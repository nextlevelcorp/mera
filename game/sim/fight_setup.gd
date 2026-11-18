class_name FightSetup
extends RefCounted
## Builds the context of a fight (the same dictionary CatchModel and FightSim
## take) from a loaded database. Used by the fight screen with the demo data.

const TACKLES := ["lrf", "spin", "capari", "float"]
## The float rig fishes this bait under this float (R12).
const FLOAT_BAIT := "shrimp"
const FLOAT_RIG := "float_rig"

## database: DataStore.load_all(...)["database"]; species_id, tackle (lrf or
## spin), position_id; u is a 0..1 draw for the fish size. play_overrides
## replaces play values (cast_m, hook_distance_m, timing_quality) with what
## happened in the cast and the strike.
static func build(database: Dictionary, species_id: String, tackle: String, position_id: String, u: float, conditions: Dictionary, play_overrides: Dictionary = {}) -> Dictionary:
	var spot: Dictionary = database["spot"][0]
	var position: Dictionary = {}
	for p: Dictionary in spot["positions"]:
		if p["id"] == position_id:
			position = p
	var species := _by_id(database["species"], species_id)
	var rod := _by_id(database["rod"], "%s_rod" % tackle)
	var reel := _by_id(database["reel"], "%s_reel" % tackle)
	var ctx := {
		"species": species, "spot": spot, "position": position,
		"rod": rod, "reel": reel,
		"line": _by_id(database["line"], "%s_line" % tackle),
		"leader": _by_id(database["leader"], "%s_leader" % tackle),
		"lure": _by_id(database["lure"], lure_id(tackle)) if tackle != "float" else float_lure(database, play_overrides),
		"angler": database["angler"][0],
		"conditions": conditions,
		"play": {
			"cast_m": 20.0, "lure_depth_m": 3.0, "retrieve_speed": 11.0, "timing_quality": 0.8,
			"fish_length_cm": FightController.draw_length_cm(species, u),
			"drag_kg": float(reel["drag_max_kg"]) / 3.0, "hook_distance_m": 26.0,
		},
	}
	if tackle == "float":
		# The bait waits at the float's depth and barely moves.
		ctx["play"]["lure_depth_m"] = ctx["lure"]["run_depth_max_m"]
		ctx["play"]["retrieve_speed"] = 1.0
	(ctx["play"] as Dictionary).merge(play_overrides, true)
	ctx["play"].erase("float_depth_m")
	return ctx


## The float rig's lure-shaped record; play_overrides may carry float_depth_m.
static func float_lure(database: Dictionary, play_overrides: Dictionary = {}) -> Dictionary:
	var f := _by_id(database.get("float", []), FLOAT_RIG)
	var depth := float(play_overrides.get("float_depth_m", f["depth_default_m"]))
	return Presentation.float_lure(_by_id(database.get("bait", []), FLOAT_BAIT), f, depth)


## Lure id of a rig (the demo has one lure per rig).
static func lure_id(tackle: String) -> String:
	return {"lrf": "lrf_soft", "spin": "spin_minnow", "capari": "capari_rig", "float": FLOAT_BAIT}.get(tackle, "lrf_soft")


static func _by_id(records: Array, id: String) -> Dictionary:
	for r: Dictionary in records:
		if r["id"] == id:
			return r
	return {}
