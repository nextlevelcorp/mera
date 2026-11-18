class_name Presentation
extends RefCounted
## How the hook is offered to the fish (roadmap R12; data_model.md 5.2). A
## lure is fished as it is (lures.json). A float rig hangs a natural bait
## (baits.json) under a float (floats.json) at a depth the angler sets: the
## bait stays at that depth and barely moves, and its scent draws fish that
## cannot see it well. This builds the lure-shaped record the catch model
## and WaitSim read, so every stage works on both. Pure.

const FLOAT := "float"


## The record the catch model reads for bait under a float at depth_m.
static func float_lure(bait: Dictionary, float_rec: Dictionary, depth_m: float) -> Dictionary:
	var depth := clamp_depth(float_rec, depth_m)
	return {
		"id": bait["id"], "name_key": bait["name_key"], "type": "bait", "presentation": FLOAT,
		"length_cm": float(bait["size_cm"]), "weight_g": float(float_rec["weight_g"]),
		"flash": 1, "action": 2, "scent": int(bait["scent"]), "durability": int(bait["durability"]),
		"imitates": bait["target_diet_tags"],
		"run_depth_min_m": depth, "run_depth_max_m": depth, "sink_rate_m_per_s": 0.0,
		"hook_gape_mm": float(float_rec["hook_gape_mm"]), "hook_pattern": "single",
		"float_id": float_rec["id"],
	}


static func clamp_depth(float_rec: Dictionary, depth_m: float) -> float:
	return clampf(depth_m, float(float_rec["depth_min_m"]), float(float_rec["depth_max_m"]))


static func is_float(lure: Dictionary) -> bool:
	return String(lure.get("presentation", "")) == FLOAT
