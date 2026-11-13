class_name FightSetup
extends RefCounted
## Builds the context of a fight (the same dictionary CatchModel and FightSim
## take) from a loaded database. Used by the fight screen with the demo data.

const TACKLES := ["lrf", "spin"]

## database: DataStore.load_all(...)["database"]; species_id, tackle (lrf or
## spin), position_id; u is a 0..1 draw for the fish size.
static func build(database: Dictionary, species_id: String, tackle: String, position_id: String, u: float, conditions: Dictionary) -> Dictionary:
	var spot: Dictionary = database["spot"][0]
	var position: Dictionary = {}
	for p: Dictionary in spot["positions"]:
		if p["id"] == position_id:
			position = p
	var species := _by_id(database["species"], species_id)
	var lure_id := "lrf_soft" if tackle == "lrf" else "spin_minnow"
	var rod := _by_id(database["rod"], "%s_rod" % tackle)
	var reel := _by_id(database["reel"], "%s_reel" % tackle)
	return {
		"species": species, "spot": spot, "position": position,
		"rod": rod, "reel": reel,
		"line": _by_id(database["line"], "%s_line" % tackle),
		"leader": _by_id(database["leader"], "%s_leader" % tackle),
		"lure": _by_id(database["lure"], lure_id),
		"angler": database["angler"][0],
		"conditions": conditions,
		"play": {
			"cast_m": 20.0, "lure_depth_m": 3.0, "retrieve_speed": 11.0, "timing_quality": 0.8,
			"fish_length_cm": FightController.draw_length_cm(species, u),
			"drag_kg": float(reel["drag_max_kg"]) / 3.0, "hook_distance_m": 26.0,
		},
	}


static func _by_id(records: Array, id: String) -> Dictionary:
	for r: Dictionary in records:
		if r["id"] == id:
			return r
	return {}
