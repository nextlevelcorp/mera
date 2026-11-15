class_name WhyReport
extends RefCounted
## The player's "why" view (PRD F10, pillar 2: realism you can read). Turns
## the model's stage numbers for one catch attempt into a few lines the
## player can reason about: depth, feeding time, tackle match, line tension
## and the reason for the outcome. Pure and deterministic. Returns
## translation keys with their arguments; the screen translates them, so no
## user-facing text lives here.

const GOOD := 0.75
const FAIR := 0.4


## Words for how well a 0..1 fit worked: good, fair or poor (not colour alone).
static func grade_key(fit: float) -> String:
	if fit >= GOOD:
		return "WHY_GOOD"
	if fit >= FAIR:
		return "WHY_FAIR"
	return "WHY_POOR"


## resolved: CatchModel.resolve for the fight's context. species_name and
## slot_name are already translated. stats: max_tension_kg, drag_kg,
## line_strength_kg, distance_m, cap_applied. Returns [{key, args}].
static func lines(resolved: Dictionary, ctx: Dictionary, species_name: String, slot_name: String, outcome: String, stats: Dictionary) -> Array[Dictionary]:
	var sp: Dictionary = ctx["species"]
	var lure: Dictionary = ctx["lure"]
	var pres: Dictionary = resolved["presence"]
	var attr: Dictionary = resolved["attraction"]
	var hk: Dictionary = resolved["hook"]
	var out: Array[Dictionary] = []
	var depth_fit := minf(float(pres["D"]), float(attr["G"]))
	out.append({"key": "WHY_DEPTH", "args": [
		float(pres["inputs"]["water_depth_m"]), species_name,
		float(sp["feeding_depth_min_m"]), float(sp["feeding_depth_max_m"]),
		float(ctx["play"]["lure_depth_m"]), grade_key(depth_fit)]})
	out.append({"key": "WHY_TIME", "args": [
		species_name, 100.0 * float(pres["inputs"]["activity"]), slot_name, grade_key(float(pres["inputs"]["activity"]))]})
	out.append({"key": "WHY_TACKLE", "args": [
		float(lure["length_cm"]), float(sp["mouth_gape_mm"]), grade_key(float(attr["Z"])),
		float(lure["hook_gape_mm"]), grade_key(float(hk["H1"]))]})
	var strength := float(stats["line_strength_kg"])
	out.append({"key": "WHY_TENSION", "args": [
		float(stats["max_tension_kg"]), strength, 100.0 * float(stats["max_tension_kg"]) / maxf(strength, 0.001), float(stats["drag_kg"])]})
	out.append(_outcome_line(resolved, outcome, stats))
	return out


static func _outcome_line(resolved: Dictionary, outcome: String, stats: Dictionary) -> Dictionary:
	match outcome:
		FightSim.OUTCOME_LANDED:
			return {"key": "WHY_OUT_LANDED", "args": []}
		FightSim.OUTCOME_LINE_BREAK:
			return {"key": "WHY_OUT_LINE_BREAK", "args": [float(stats["max_tension_kg"]), float(stats["line_strength_kg"]), float(stats["drag_kg"])]}
		FightSim.OUTCOME_LEADER_CUT:
			return {"key": "WHY_OUT_LEADER_CUT", "args": [float(resolved["fight"]["inputs"]["teeth"])]}
		FightSim.OUTCOME_HOOK_PULLED:
			if bool(stats.get("cap_applied", false)):
				return {"key": "WHY_OUT_HOOK_CAP", "args": [float(stats.get("distance_m", 0.0))]}
			if bool(stats.get("thrown_on_jump", false)):
				return {"key": "WHY_OUT_JUMP", "args": [100.0 * float(resolved["hook"]["hook"])]}
			return {"key": "WHY_OUT_HOOK_SLACK", "args": [100.0 * float(resolved["hook"]["hook"])]}
		FightSim.OUTCOME_LOST_AT_EDGE:
			return {"key": "WHY_OUT_LOST_AT_EDGE", "args": [100.0 * float(resolved["landing"]["landing_q"])]}
	return {"key": "WHY_OUT_LANDED", "args": []}
