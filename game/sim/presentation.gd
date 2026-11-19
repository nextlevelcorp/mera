class_name Presentation
extends RefCounted
## How the hook is offered to the fish (roadmap R12; data_model.md 5.2). A
## lure is fished as it is (lures.json). A float rig hangs a natural bait
## (baits.json) under a float (floats.json) at a depth the angler sets: the
## bait stays at that depth and barely moves, and its scent draws fish that
## cannot see it well. This builds the lure-shaped record the catch model
## and WaitSim read, so every stage works on both. A live bait (a bait with
## from_species) is a fish from the bag: only one of legal size may be used,
## and it swims (its action), so it suits the hunters. Pure.

const FLOAT := "float"


## The record the catch model reads for bait under a float at depth_m.
## vigor (0..1) is how lively a live bait still is: it swims less as it tires.
static func float_lure(bait: Dictionary, float_rec: Dictionary, depth_m: float, vigor: float = 1.0) -> Dictionary:
	var depth := clamp_depth(float_rec, depth_m)
	return {
		"id": bait["id"], "name_key": bait["name_key"], "type": "bait", "presentation": FLOAT,
		"length_cm": float(bait["size_cm"]), "weight_g": float(float_rec["weight_g"]),
		"flash": 1, "action": maxi(int(roundf(float(bait.get("action", 1)) * clampf(vigor, 0.0, 1.0))), 1), "scent": int(bait["scent"]), "durability": int(bait["durability"]),
		"imitates": bait["target_diet_tags"],
		"run_depth_min_m": depth, "run_depth_max_m": depth, "sink_rate_m_per_s": 0.0,
		"hook_gape_mm": float(bait.get("hook_gape_mm", float_rec["hook_gape_mm"])), "hook_pattern": "single",
		"float_id": float_rec["id"],
	}


static func clamp_depth(float_rec: Dictionary, depth_m: float) -> float:
	return clampf(depth_m, float(float_rec["depth_min_m"]), float(float_rec["depth_max_m"]))


static func is_float(lure: Dictionary) -> bool:
	return String(lure.get("presentation", "")) == FLOAT


## The bag's fish a live bait may be made from: that species, at least its
## legal length (an undersize fish goes back, not on the hook). Bag indexes,
## smallest fish first.
static func live_bait_fish(save: Dictionary, bait: Dictionary, species: Dictionary) -> Array[int]:
	var want := Inventory.FISH_PREFIX + String(bait["from_species"])
	var legal := float((species.get("regulation", {}) as Dictionary).get("min_length_cm", 0.0))
	var out: Array[int] = []
	var items := Inventory.items(save)
	for i in items.size():
		if items[i]["id"] == want and float(items[i]["meta"].get("length_cm", 0.0)) >= legal:
			out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool: return float(items[a]["meta"]["length_cm"]) < float(items[b]["meta"]["length_cm"]))
	return out


## How many casts the bag has for this bait.
static func bait_stock(save: Dictionary, bait: Dictionary, species_records: Array) -> int:
	if bait.has("from_species"):
		return live_bait_fish(save, bait, _by_id(species_records, bait["from_species"])).size()
	return Inventory.count(save, bait["id"])


## Uses one bait for a cast: a piece from the stock, or the smallest legal
## fish of the bait's species. False if there is none.
static func use_bait(save: Dictionary, bait: Dictionary, species_records: Array) -> bool:
	if bait.has("from_species"):
		var fish := live_bait_fish(save, bait, _by_id(species_records, bait["from_species"]))
		if fish.is_empty():
			return false
		Inventory.items(save).remove_at(fish[0])
		return true
	return Inventory.remove(save, bait["id"])


static func _by_id(records: Array, id: String) -> Dictionary:
	for r: Dictionary in records:
		if r["id"] == id:
			return r
	return {}
