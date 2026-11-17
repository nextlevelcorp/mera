class_name Progress
extends RefCounted
## The angler gets better by fishing (roadmap R9; architecture.md 7). Three
## skills earn experience from what the player does, and each skill's level
## raises the angler attributes the catch model already reads:
##   cast    casting_distance and casting_accuracy (CatchModel.cast)
##   strike  strike_timing (a wider strike window, WaitSim)
##   knots   knot_strength (the knot's share of line strength, CatchModel.fight)
## Pure functions over the save (optional key angler_xp). All numbers are
## design fills in constants.json (XP_*); the formulas are in data_model.md 15.

const SKILLS: Array[String] = ["cast", "strike", "knots"]
const ATTRIBUTES := {
	"cast": ["casting_distance", "casting_accuracy"],
	"strike": ["strike_timing"],
	"knots": ["knot_strength"],
}
const MAX_LEVEL := 10


static func xp(save: Dictionary, skill: String) -> int:
	return int((save.get("angler_xp", {}) as Dictionary).get(skill, 0))


## Level 1..MAX_LEVEL from experience: level n needs XP_LEVEL_BASE x (n - 1)^2.
static func level(k: Dictionary, xp_points: int) -> int:
	return clampi(1 + int(floor(sqrt(float(maxi(xp_points, 0)) / float(k["XP_LEVEL_BASE"])))), 1, MAX_LEVEL)


static func xp_for_level(k: Dictionary, lvl: int) -> int:
	return int(float(k["XP_LEVEL_BASE"]) * pow(float(lvl - 1), 2.0))


## The experience an event is worth. event: {type: cast, power} | {type:
## hooked, timing} | {type: landed, peak_ratio}. Returns {skill: points}.
static func points(k: Dictionary, event: Dictionary) -> Dictionary:
	match String(event.get("type", "")):
		"cast":
			var good := float(event.get("power", 0.0)) >= float(k["XP_CAST_GOOD_POWER"])
			return {"cast": int(k["XP_CAST"]) + (int(k["XP_CAST_GOOD"]) if good else 0)}
		"hooked":
			return {"strike": int(k["XP_STRIKE"]) + int(roundf(float(k["XP_STRIKE_TIMING"]) * clampf(float(event.get("timing", 0.0)), 0.0, 1.0)))}
		"landed":
			var loaded := float(event.get("peak_ratio", 0.0)) >= float(k["STRAIN_SHARE"])
			return {"knots": int(k["XP_KNOTS"]) + (int(k["XP_KNOTS_LOADED"]) if loaded else 0)}
	return {}


## Adds an event's experience to the save. Returns {gained: {skill: points},
## level_ups: [skill]} so the screen can say what happened.
static func award(save: Dictionary, k: Dictionary, event: Dictionary) -> Dictionary:
	if not save.has("angler_xp") or typeof(save["angler_xp"]) != TYPE_DICTIONARY:
		save["angler_xp"] = {}
	var gained := points(k, event)
	var ups: Array[String] = []
	for skill: String in gained:
		var before := level(k, xp(save, skill))
		save["angler_xp"][skill] = xp(save, skill) + int(gained[skill])
		if level(k, xp(save, skill)) > before:
			ups.append(skill)
	return {"gained": gained, "level_ups": ups}


## The angler record with the skills' levels added: each level above 1 adds
## one point to its attributes, up to 20.
static func angler(base: Dictionary, save: Dictionary, k: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for skill: String in SKILLS:
		var bonus := level(k, xp(save, skill)) - 1
		for attr: String in ATTRIBUTES[skill]:
			out[attr] = clampf(float(base[attr]) + bonus, 1.0, 20.0)
	return out


## The strike window grows with strike timing, relative to the default angler
## (attribute 10), so the default reproduces the model's numbers.
static func strike_window_factor(k: Dictionary, angler_record: Dictionary) -> float:
	return 1.0 + float(k["STRIKE_SKILL_WINDOW"]) * (CatchModel.n(float(angler_record.get("strike_timing", 10))) - CatchModel.n(10.0))
