class_name Mastery
extends RefCounted
## The mastery progression (roadmap R22, owner decision D8): goals that become
## badges, a rank from the badges, and the next goal to show. Everything is
## read from what the save already keeps (the catch log with counts and best
## lengths, the counters, the skills' experience, the quests done), so this
## adds no save data. No timers, no energy, nothing lost. Pure; the goals are
## design fills in game/data/goals.json, the rank steps in constants.json.

const FILE := "res://data/goals.json"
const KINDS: Array[String] = ["fish_landed", "species_caught", "species_count", "record_length", "skill_level", "quests_done", "casts"]


## Reads and checks the goals. Returns {"ok", "errors", "goals"}.
static func load_goals(database: Dictionary) -> Dictionary:
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f == null:
		return {"ok": false, "errors": ["cannot open %s" % FILE], "goals": []}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["%s is not a JSON object" % FILE], "goals": []}
	return validate(d, database)


static func validate(d: Dictionary, database: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if d.get("design_fill") != true and not d.has("source"):
		errors.append("goals: needs design_fill or a source")
	var species := {}
	for s: Dictionary in database.get("species", []):
		species[s["id"]] = s
	var seen := {}
	for g: Dictionary in d.get("goals", []):
		var id := String(g.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("goal id missing or repeated: %s" % id)
		seen[id] = true
		if not String(g.get("kind", "")) in KINDS:
			errors.append("%s: unknown kind %s" % [id, g.get("kind")])
		if typeof(g.get("target")) not in [TYPE_INT, TYPE_FLOAT] or float(g["target"]) <= 0.0:
			errors.append("%s: target must be above 0" % id)
		if g.get("kind") in ["species_count", "record_length"]:
			if not species.has(g.get("species", "")):
				errors.append("%s: unknown species %s" % [id, g.get("species")])
			elif g["kind"] == "record_length" and float(g["target"]) > float(species[g["species"]]["length_max_cm"]):
				errors.append("%s: record target above the species' sourced length range" % id)
		if g.get("kind") == "skill_level" and not String(g.get("skill", "")) in Progress.SKILLS:
			errors.append("%s: unknown skill %s" % [id, g.get("skill")])
	return {"ok": errors.is_empty(), "errors": errors, "goals": d.get("goals", [])}


## How far the player is on one goal: {"value", "target", "done"}.
static func progress(goal: Dictionary, save: Dictionary, k: Dictionary) -> Dictionary:
	var log: Dictionary = save.get("log", {})
	var value := 0.0
	match String(goal["kind"]):
		"fish_landed":
			value = float((save.get("stats", {}) as Dictionary).get("fish_landed", 0))
		"species_caught":
			value = float(log.size())
		"species_count":
			value = float((log.get(goal["species"], {}) as Dictionary).get("count", 0))
		"record_length":
			value = float((log.get(goal["species"], {}) as Dictionary).get("best_length_cm", 0.0))
		"skill_level":
			value = float(Progress.level(k, Progress.xp(save, String(goal["skill"]))))
		"quests_done":
			value = float(((save.get("quests", {}) as Dictionary).get("done", []) as Array).size())
		"casts":
			value = float((save.get("stats", {}) as Dictionary).get("casts", 0))
	var target := float(goal["target"])
	return {"value": value, "target": target, "done": value >= target}


## The ids of the goals reached, in the goals' order: the badges.
static func badges(goals: Array, save: Dictionary, k: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for g: Dictionary in goals:
		if progress(g, save, k)["done"]:
			out.append(String(g["id"]))
	return out


## The goal to show next: of those not reached, the nearest to done (by
## share of the target), the earlier one on a tie. Empty when all are done.
static func next_goal(goals: Array, save: Dictionary, k: Dictionary) -> Dictionary:
	var best := {}
	var best_share := -1.0
	for g: Dictionary in goals:
		var p := progress(g, save, k)
		if p["done"]:
			continue
		var share := share_of(g, p)
		if share > best_share:
			best_share = share
			best = g
	return best


## How far along a goal is, 0..1. Skills start at level 1, so a skill goal
## counts from there: (level - 1) / (target - 1).
static func share_of(goal: Dictionary, p: Dictionary) -> float:
	var v := float(p["value"])
	var t := float(p["target"])
	if goal["kind"] == "skill_level":
		return clampf((v - 1.0) / maxf(t - 1.0, 1.0), 0.0, 1.0)
	return clampf(v / t, 0.0, 1.0)


## The rank (0..) from the number of badges: the highest step reached.
static func rank(badge_count: int, k: Dictionary) -> int:
	var r := 0
	var steps: Array = k["RANK_STEPS"]
	for i in steps.size():
		if badge_count >= int(steps[i]):
			r = i
	return r


## The badges in after that were not in before (what to announce).
static func earned(before: Array, after: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in after:
		if not before.has(id):
			out.append(String(id))
	return out
