class_name CatchModel
extends RefCounted
## Staged catch resolution, docs/data_model.md section 5. Pure functions: no
## nodes, no globals, no randomness. Every stage returns a Dictionary that holds
## the inputs it used ("inputs") next to its results, so the "why" view and the
## tests read the same record (PRD F10).
##
## Not ported yet (see the PR notes): the cast distance model (5.0), the
## shoal follow-up after a take (5.3) and the real-time fight tick model (5.5).
## The fight here is the closed-form estimate at a constant drag.

## Attribute 1-20 -> 0..1.
static func n(attribute: float) -> float:
	return (attribute - 1.0) / 19.0


## 1 inside [lo, hi], falling linearly to 0 at distance `margin` outside.
static func band(x: float, lo: float, hi: float, margin: float) -> float:
	if x >= lo and x <= hi:
		return 1.0
	var distance: float = lo - x if x < lo else x - hi
	return clampf(1.0 - distance / margin, 0.0, 1.0)


## profile: Array of {distance_m, depth_m}, sorted by distance.
static func depth_at(profile: Array, distance_m: float) -> float:
	var first: Dictionary = profile[0]
	if distance_m <= float(first["distance_m"]):
		return float(first["depth_m"])
	for i in range(1, profile.size()):
		var a: Dictionary = profile[i - 1]
		var b: Dictionary = profile[i]
		if distance_m <= float(b["distance_m"]):
			var t := (distance_m - float(a["distance_m"])) / (float(b["distance_m"]) - float(a["distance_m"]))
			return lerpf(float(a["depth_m"]), float(b["depth_m"]), t)
	return float((profile[profile.size() - 1] as Dictionary)["depth_m"])


## ctx keys:
##   species, spot, position, rod, reel, line, leader, lure, angler (records)
##   conditions {slot, month, wind_dir, wind_ms}
##   play {cast_m, lure_depth_m, retrieve_speed, timing_quality, fish_length_cm, drag_kg, hook_distance_m}
## k: the constants block of data/constants.json.
static func resolve(ctx: Dictionary, k: Dictionary) -> Dictionary:
	var species: Dictionary = ctx["species"]
	var spot: Dictionary = ctx["spot"]
	var position: Dictionary = ctx["position"]
	var cond: Dictionary = ctx["conditions"]
	var play: Dictionary = ctx["play"]

	var env := environment(k, spot, position, cond)
	var water_depth := depth_at(position["depth_profile"], float(play["cast_m"]))
	var pres := presence(k, species, spot, position, cond, env, water_depth)
	var attr := attraction(k, species, ctx["lure"], play, env, water_depth)
	var com := commit(k, species, spot, ctx["rod"], ctx["leader"], env, pres["presence"], attr["attraction"])
	var hk := hook(k, species, ctx["rod"], ctx["line"], ctx["lure"], float(play["timing_quality"]))
	var fg := fight(k, species, position, ctx["reel"], ctx["line"], ctx["leader"], ctx["angler"], play)
	var land := landing(k, position, env, float(fg["W_kg"]), float(fg["Beff"]))

	# P(landed | take, strike in the window): zero if the line breaks; otherwise the
	# hook must hold, the leader must not be cut by teeth, and the landing must work.
	var p_land: float = 0.0 if fg["line_breaks"] else float(hk["hook"]) * (1.0 - float(fg["p_cut"])) * float(land["landing_q"])
	return {
		"environment": env,
		"water_depth_m": water_depth,
		"presence": pres,
		"attraction": attr,
		"commit": com,
		"hook": hk,
		"fight": fg,
		"landing": land,
		"chain": {"inputs": {"hook": hk["hook"], "p_cut": fg["p_cut"], "landing_q": land["landing_q"], "line_breaks": fg["line_breaks"]}, "p_land_given_take": p_land},
	}


## Sum of take rates (per second) over every species at the spot, with the same
## tackle and play. median wait for any take = ln(2) / total.
static func total_take_rate(ctx: Dictionary, k: Dictionary, species_records: Array) -> float:
	var total := 0.0
	var spot: Dictionary = ctx["spot"]
	for entry: Dictionary in spot["species"]:
		for sp: Dictionary in species_records:
			if sp["id"] == entry["species_id"]:
				var c := ctx.duplicate()
				c["species"] = sp
				total += float(resolve(c, k)["commit"]["rate_take"])
	return total


static func median_wait_s(rate_per_s: float) -> float:
	return log(2.0) / rate_per_s if rate_per_s > 0.0 else INF


# ------------------------------------------------------------------ stage 0

static func environment(k: Dictionary, spot: Dictionary, position: Dictionary, cond: Dictionary) -> Dictionary:
	var exposure: float = float(position["exposure_by_wind"][cond["wind_dir"]])
	var chop: float = exposure * minf(float(cond["wind_ms"]) / 10.0, 1.0)
	var clarity: float = clampf(float(spot["typical_clarity"]) - float(k["CHOP_CLARITY"]) * chop, 1.0, 20.0)
	var light: float = float(k["LIGHT"][cond["slot"]])
	return {
		"inputs": {"exposure": exposure, "wind_ms": float(cond["wind_ms"]), "typical_clarity": float(spot["typical_clarity"]), "slot": cond["slot"]},
		"chop": chop, "clarity_eff": clarity, "light": light, "visibility": n(clarity) * light,
	}


# ------------------------------------------------------------------ stage 1

static func presence(k: Dictionary, sp: Dictionary, spot: Dictionary, position: Dictionary, cond: Dictionary, env: Dictionary, water_depth: float) -> Dictionary:
	var abundance := 0.0
	for entry: Dictionary in spot["species"]:
		if entry["species_id"] == sp["id"]:
			abundance = float(entry["abundance_by_month"][int(cond["month"]) - 1])
	var activity: float = float(sp["activity_by_slot"][cond["slot"]])
	var d_min: float = float(sp["feeding_depth_min_m"])
	var d_max: float = float(sp["feeding_depth_max_m"])
	var depth_fit: float = clampf((water_depth - d_min) / (0.5 * (d_max - d_min)), 0.0, 1.0)
	var water_temp: float = float(spot["water_temp_by_month_c"][int(cond["month"]) - 1])
	var temp_fit := band(water_temp, float(sp["temp_min_c"]), float(sp["temp_max_c"]), float(k["TEMP_M"]))
	var structure: float = float(k["STRUCT_BASE"]) + (1.0 - float(k["STRUCT_BASE"])) * n(float(position["structure"]))
	return {
		"inputs": {"abundance": abundance, "activity": activity, "water_depth_m": water_depth, "water_temp_c": water_temp, "structure": float(position["structure"])},
		"D": depth_fit, "Theta": temp_fit, "S": structure,
		"presence": abundance * activity * depth_fit * temp_fit * structure,
	}


# ------------------------------------------------------------------ stage 2

static func attraction(k: Dictionary, sp: Dictionary, lure: Dictionary, play: Dictionary, env: Dictionary, water_depth: float) -> Dictionary:
	var d_min: float = float(sp["feeding_depth_min_m"])
	var d_max: float = float(sp["feeding_depth_max_m"])
	var lure_depth: float = float(play["lure_depth_m"])
	var margin: float = float(k["REACH_BASE"]) + float(k["REACH_CLAR"]) * n(float(env["clarity_eff"]))
	var reach := band(lure_depth, d_min, minf(d_max, water_depth), margin)
	var diet_match := 1.0 if _shares_tag(lure["imitates"], sp["diet_tags"]) else float(k["DIET_MISS"])
	var gape_cm: float = float(sp["mouth_gape_mm"]) / 10.0
	var size_fit := band(float(lure["length_cm"]), float(k["SIZE_LO"]) * gape_cm, float(k["SIZE_HI"]) * gape_cm, float(k["SIZE_M"]) * gape_cm)
	var speed_fit: float = 1.0 - float(k["SPEED_PEN"]) * absf(n(float(play["retrieve_speed"])) - n(float(sp["speed"])))
	var vis: float = float(env["visibility"])
	var detect: float = float(k["DETECT_BASE"]) + (1.0 - float(k["DETECT_BASE"])) * (vis + (1.0 - vis) * (0.5 * n(float(lure["flash"])) + 0.5 * n(float(lure["action"]))))
	return {
		"inputs": {"lure_depth_m": lure_depth, "lure_length_cm": float(lure["length_cm"]), "retrieve_speed": float(play["retrieve_speed"]), "visibility": vis},
		"G": reach, "M": diet_match, "Z": size_fit, "V": speed_fit, "F": detect,
		"attraction": reach * diet_match * size_fit * speed_fit * detect,
	}


# ------------------------------------------------------------------ stage 3

static func commit(k: Dictionary, sp: Dictionary, spot: Dictionary, rod: Dictionary, leader: Dictionary, env: Dictionary, presence_value: float, attraction_value: float) -> Dictionary:
	var caution := n(float(sp["caution"]))
	var suspicion: float = caution * n(float(leader["visibility"])) * float(env["visibility"])
	var pressure: float = caution * n(float(spot["pressure"]))
	var c: float = clampf(
		float(k["COMMIT_BASE"]) + float(k["COMMIT_AGG"]) * n(float(sp["aggression"])) - float(k["COMMIT_LINE"]) * suspicion - float(k["COMMIT_PRESS"]) * pressure,
		float(k["COMMIT_MIN"]), float(k["COMMIT_MAX"]))
	var rate_interest: float = float(k["R0"]) * presence_value * attraction_value
	var rate_take: float = rate_interest * c
	var window: float = float(k["TW_BASE"]) + float(k["TW_SENS"]) * n(float(rod["sensitivity"])) + float(k["TW_AGG"]) * n(float(sp["aggression"]))
	return {
		"inputs": {"presence": presence_value, "attraction": attraction_value, "leader_visibility": float(leader["visibility"]), "caution": float(sp["caution"]), "aggression": float(sp["aggression"])},
		"suspicion": suspicion, "pressure": pressure, "commit": c,
		"rate_interest": rate_interest, "rate_take": rate_take,
		"median_wait_s": median_wait_s(rate_take), "strike_window_s": window,
	}


# ------------------------------------------------------------------ stage 4

static func hook(k: Dictionary, sp: Dictionary, rod: Dictionary, line: Dictionary, lure: Dictionary, timing_quality: float) -> Dictionary:
	var mouth: float = float(sp["mouth_gape_mm"])
	var gape_fit := band(float(lure["hook_gape_mm"]), float(k["GAPE_LO"]) * mouth, float(k["GAPE_HI"]) * mouth, float(k["GAPE_M"]) * mouth)
	var penetration: float = float(k["PEN_BASE"]) + (1.0 - float(k["PEN_BASE"])) * (0.5 * n(float(rod["power"])) + 0.5 * (1.0 - n(float(line["stretch"]))))
	var timing: float = float(k["TIMING_BASE"]) + (1.0 - float(k["TIMING_BASE"])) * timing_quality
	return {
		"inputs": {"hook_gape_mm": float(lure["hook_gape_mm"]), "mouth_gape_mm": mouth, "rod_power": float(rod["power"]), "line_stretch": float(line["stretch"]), "timing_quality": timing_quality},
		"H1": gape_fit, "H2": penetration, "H3": timing,
		"hook": clampf(gape_fit * penetration * timing, 0.0, float(k["HOOK_MAX"])),
	}


# ------------------------------------------------------------------ stage 5

## Closed-form estimate at a constant drag. t_fight_capped applies the 90 s rule
## (PRD F8); cap_applied says whether the uncapped estimate would exceed it.
static func fight(k: Dictionary, sp: Dictionary, position: Dictionary, reel: Dictionary, line: Dictionary, leader: Dictionary, angler: Dictionary, play: Dictionary) -> Dictionary:
	var length_cm: float = float(play["fish_length_cm"])
	var weight_kg: float = float(sp["lw_a"]) * pow(length_cm, float(sp["lw_b"])) / 1000.0
	var f_max: float = weight_kg * (float(k["PULL_BASE"]) + float(k["PULL_STR"]) * n(float(sp["strength"])))
	var energy: float = f_max * (float(k["STA_BASE"]) + float(k["STA_RANGE"]) * n(float(sp["stamina"])))
	var weakest: float = minf(float(line["breaking_strain_kg"]), float(leader["breaking_strain_kg"]))
	var knot: float = float(k["KNOT_BASE"]) + float(k["KNOT_SKILL"]) * n(float(angler["knot_strength"]))
	var abrasion: float = 1.0 - float(k["ABRASION"]) * n(float(position["structure"])) * (1.0 - n(float(leader["abrasion_resistance"])))
	var b_eff: float = weakest * knot * abrasion
	var drag: float = float(play["drag_kg"])
	var spike: float = drag * (1.0 + float(k["SPIKE"]) * (1.0 - n(float(reel["smoothness"]))))
	var t_bar: float = minf(drag, f_max)
	var t_tire: float = (1.0 - float(k["LAND_ENERGY"])) * energy / (t_bar + float(k["REST_DRAIN"]) * f_max)
	var t_reel: float = float(play["hook_distance_m"]) / float(reel["retrieve_m_per_s"])
	var t_fight: float = maxf(t_tire, t_reel) + float(k["LAND_PHASE"])
	var cap: float = float(k["FIGHT_CAP_S"])
	var t_capped: float = minf(t_fight, cap)
	# Teeth cut the leader at a constant hazard over the (capped) fight; wire is immune.
	var cut_factor: float = float(k["WIRE_CUT_FACTOR"]) if leader["type"] == "wire" else 1.0
	var cut_rate: float = float(k["TEETH_RATE"]) * n(float(sp["teeth"])) * (1.0 - n(float(leader["abrasion_resistance"]))) * cut_factor
	var p_cut: float = 1.0 - exp(-cut_rate * t_capped)
	return {
		"inputs": {"fish_length_cm": length_cm, "drag_kg": drag, "line_breaking_kg": float(line["breaking_strain_kg"]), "leader_breaking_kg": float(leader["breaking_strain_kg"]), "knot_strength": float(angler["knot_strength"]), "structure": float(position["structure"]), "hook_distance_m": float(play["hook_distance_m"]), "teeth": float(sp["teeth"]), "leader_type": leader["type"], "leader_abrasion_resistance": float(leader["abrasion_resistance"])},
		"W_kg": weight_kg, "Fmax_kgf": f_max, "E0": energy, "Beff": b_eff, "spike": spike, "line_breaks": spike > b_eff,
		"Tbar": t_bar, "t_tire": t_tire, "t_reel": t_reel, "t_fight": t_fight,
		"t_fight_capped": t_capped, "cap_applied": t_fight > cap, "cut_rate_per_s": cut_rate, "p_cut": p_cut,
	}


# ------------------------------------------------------------------ stage 6

static func landing(k: Dictionary, position: Dictionary, env: Dictionary, weight_kg: float, b_eff: float) -> Dictionary:
	var difficulty: float = float(position["landing_difficulty"])
	var q: float = 1.0 - clampf(weight_kg / b_eff - float(k["LAND_FREE"]), 0.0, 1.0) * difficulty
	return {
		"inputs": {"weight_kg": weight_kg, "line_strength_kg": b_eff, "landing_difficulty": difficulty, "visibility": float(env["visibility"])},
		"landing_q": q,
		"visible_at_m": float(k["VIS_BASE"]) + float(k["VIS_RANGE"]) * float(env["visibility"]),
	}


static func _shares_tag(a: Array, b: Array) -> bool:
	for tag: Variant in a:
		if b.has(tag):
			return true
	return false
