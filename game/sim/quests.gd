class_name Quests
extends RefCounted
## Quests given by the people of the world (roadmap R11; architecture.md 7).
## A quest asks for fish from the bag: a species, how many, and at least the
## legal size (or a longer minimum). Handing them over removes them from the
## bag and pays the reward: money, stackable items (lures) and experience.
## Each giver offers their quests one after another. Pure functions over the
## save (optional key quests: {active: [id], done: [id]}); the quests are
## design fills in game/data/quests.json.

const FILE := "res://data/quests.json"


## Loads and validates the quests against the roster, species and shop.
## Returns {"ok", "errors", "quests"}.
static func load_quests(npcs: Array, database: Dictionary, shop: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var raw: Variant = DataStore.read_json(FILE, errors)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "errors": errors, "quests": []}
	var d: Dictionary = raw
	if d.get("design_fill", false) != true and not d.has("source"):
		errors.append("quests: needs a source or design_fill true")
	var givers := {}
	for n: Dictionary in npcs:
		givers[n["id"]] = true
	var species := {}
	for s: Dictionary in database.get("species", []):
		species[s["id"]] = true
	var items := {}
	for l: Dictionary in shop.get("lures", []):
		items[l["id"]] = true
	var seen := {}
	for q: Dictionary in d.get("quests", []):
		var id := String(q.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("quests: missing or duplicate id %s" % id)
		seen[id] = true
		if not givers.has(String(q.get("giver", ""))):
			errors.append("quests:%s: unknown giver" % id)
		for key: String in ["title_key", "ask_key", "thanks_key"]:
			if String(q.get(key, "")) == "":
				errors.append("quests:%s: missing %s" % [id, key])
		var need: Dictionary = q.get("need", {})
		if not species.has(String(need.get("species", ""))) or int(need.get("count", 0)) < 1:
			errors.append("quests:%s: needs a known species and a count" % id)
		var reward: Dictionary = q.get("reward", {})
		for item: String in (reward.get("items", {}) as Dictionary):
			if not items.has(item):
				errors.append("quests:%s: reward item %s is not sold" % [id, item])
		for skill: String in (reward.get("xp", {}) as Dictionary):
			if not skill in Progress.SKILLS:
				errors.append("quests:%s: unknown skill %s" % [id, skill])
	return {"ok": errors.is_empty(), "errors": errors, "quests": d.get("quests", [])}


static func state(save: Dictionary) -> Dictionary:
	if not save.has("quests") or typeof(save["quests"]) != TYPE_DICTIONARY:
		save["quests"] = {"active": [], "done": []}
	return save["quests"]


static func is_active(save: Dictionary, id: String) -> bool:
	return (state(save)["active"] as Array).has(id)


static func is_done(save: Dictionary, id: String) -> bool:
	return (state(save)["done"] as Array).has(id)


## The quest this giver is on now: their first one not done. {} when all done.
static func current(quests: Array, giver: String, save: Dictionary) -> Dictionary:
	for q: Dictionary in quests:
		if q["giver"] == giver and not is_done(save, q["id"]):
			return q
	return {}


static func accept(save: Dictionary, quest: Dictionary) -> void:
	if not is_active(save, quest["id"]) and not is_done(save, quest["id"]):
		(state(save)["active"] as Array).append(quest["id"])


## The smallest length that counts: the quest's own minimum or the legal one.
static func min_length(quest: Dictionary, species: Dictionary) -> float:
	var legal := float((species.get("regulation", {}) as Dictionary).get("min_length_cm", 0.0))
	return maxf(legal, float(quest["need"].get("min_length_cm", 0.0)))


## Bag indexes of the fish that count for this quest, at most the number asked.
static func matching(save: Dictionary, quest: Dictionary, species: Dictionary) -> Array[int]:
	var want := Inventory.FISH_PREFIX + String(quest["need"]["species"])
	var least := min_length(quest, species)
	var out: Array[int] = []
	var items := Inventory.items(save)
	for i in items.size():
		var it: Dictionary = items[i]
		if it["id"] == want and float(it["meta"].get("length_cm", 0.0)) >= least:
			out.append(i)
			if out.size() == int(quest["need"]["count"]):
				break
	return out


static func can_complete(save: Dictionary, quest: Dictionary, species: Dictionary) -> bool:
	return is_active(save, quest["id"]) and matching(save, quest, species).size() >= int(quest["need"]["count"])


## Pays a reward {money, items, xp} into the save. Returns the skills that
## levelled up. Shared by quests and weekly tasks.
static func give_reward(save: Dictionary, reward: Dictionary, k: Dictionary) -> Array[String]:
	save["money"] = Economy.money(save) + int(reward.get("money", 0))
	var items: Dictionary = reward.get("items", {})
	for id: String in items:
		Inventory.add(save, id, int(items[id]))
	var ups: Array[String] = []
	var xp: Dictionary = reward.get("xp", {})
	if not xp.is_empty():
		if not save.has("angler_xp") or typeof(save["angler_xp"]) != TYPE_DICTIONARY:
			save["angler_xp"] = {}
		for skill: String in xp:
			var before := Progress.level(k, Progress.xp(save, skill))
			save["angler_xp"][skill] = Progress.xp(save, skill) + int(xp[skill])
			if Progress.level(k, Progress.xp(save, skill)) > before:
				ups.append(skill)
	return ups


## Hands the fish over and pays. Returns {ok, money, items, level_ups}.
static func complete(save: Dictionary, quest: Dictionary, species: Dictionary, k: Dictionary) -> Dictionary:
	if not can_complete(save, quest, species):
		return {"ok": false}
	var given := matching(save, quest, species)
	given.reverse()   # from the end, so earlier indexes stay valid
	for i in given:
		Inventory.items(save).remove_at(i)
	var reward: Dictionary = quest.get("reward", {})
	var ups := give_reward(save, reward, k)
	var items: Dictionary = reward.get("items", {})
	var st := state(save)
	(st["active"] as Array).erase(quest["id"])
	(st["done"] as Array).append(quest["id"])
	return {"ok": true, "money": int(reward.get("money", 0)), "items": items, "level_ups": ups}
