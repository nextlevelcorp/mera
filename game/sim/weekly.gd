class_name Weekly
extends RefCounted
## Fixed weekly tasks (roadmap R22, owner decision D8; the save change was
## approved on 2026-11-20). The same tasks every week. Progress is what the
## save's counters gained since the week started: at the first look in a new
## ISO week the current values are stored as the week's start (save key
## "weekly": {week, start: {task id: value}, claimed: [task ids]}). A done task
## is claimed once for its reward; a missed one costs nothing and is simply
## new again next week. Pure: the caller passes the date (the clock is not read).

const FILE := "res://data/weekly.json"


static func load_tasks(database: Dictionary) -> Dictionary:
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f == null:
		return {"ok": false, "errors": ["cannot open %s" % FILE], "tasks": []}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["%s is not a JSON object" % FILE], "tasks": []}
	# The tasks are goals of the same kinds (Mastery.validate) with a reward.
	var as_goals := {"design_fill": d.get("design_fill"), "goals": d.get("tasks", [])}
	if d.has("source"):
		as_goals["source"] = d["source"]
	var checked := Mastery.validate(as_goals, database)
	var errors: Array = checked["errors"]
	for t: Dictionary in d.get("tasks", []):
		if typeof(t.get("reward")) != TYPE_DICTIONARY or (t["reward"] as Dictionary).is_empty():
			errors.append("%s: needs a reward" % t.get("id"))
		if t.get("kind") in ["record_length", "species_caught", "skill_level"]:
			errors.append("%s: a weekly task counts gains, not records or levels" % t.get("id"))
	return {"ok": errors.is_empty(), "errors": errors, "tasks": d.get("tasks", [])}


## The ISO 8601 week of a "YYYY-MM-DD" date, as "YYYY-Www".
static func week_id(date: String) -> String:
	var parts := date.split("-")
	var y := int(parts[0])
	var day := _days(y, int(parts[1]), int(parts[2]))
	var weekday := posmod(day + 3, 7) + 1   # 1 = Monday (day 0 is 1970-01-01, a Thursday)
	var thursday := day - weekday + 4
	var ty := _year_of(thursday)
	var week := (thursday - _days(ty, 1, 1)) / 7 + 1
	return "%d-W%02d" % [ty, week]


## Starts a new week when the save's week is not this one. True when it did.
static func refresh(save: Dictionary, tasks: Array, k: Dictionary, date: String) -> bool:
	var week := week_id(date)
	if typeof(save.get("weekly")) == TYPE_DICTIONARY and String(save["weekly"].get("week", "")) == week:
		return false
	var start := {}
	for t: Dictionary in tasks:
		start[t["id"]] = float(Mastery.progress(t, save, k)["value"])
	save["weekly"] = {"week": week, "start": start, "claimed": []}
	return true


## {value, target, done, claimed} for a task this week.
static func progress(task: Dictionary, save: Dictionary, k: Dictionary) -> Dictionary:
	var w: Dictionary = save.get("weekly", {})
	var start := float((w.get("start", {}) as Dictionary).get(task["id"], 0.0))
	var value := maxf(float(Mastery.progress(task, save, k)["value"]) - start, 0.0)
	var target := float(task["target"])
	return {"value": value, "target": target, "done": value >= target, "claimed": (w.get("claimed", []) as Array).has(task["id"])}


## Pays a done task's reward once. {ok, level_ups}.
static func claim(save: Dictionary, task: Dictionary, k: Dictionary) -> Dictionary:
	var p := progress(task, save, k)
	if not p["done"] or p["claimed"]:
		return {"ok": false}
	var ups := Quests.give_reward(save, task["reward"], k)
	(save["weekly"]["claimed"] as Array).append(task["id"])
	return {"ok": true, "level_ups": ups}


## Days since 1970-01-01 of a calendar date (proleptic Gregorian).
static func _days(y: int, m: int, d: int) -> int:
	var yy := y - (1 if m <= 2 else 0)
	var era := (yy if yy >= 0 else yy - 399) / 400
	var yoe := yy - era * 400
	var doy := (153 * (m + (-3 if m > 2 else 9)) + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func _year_of(day: int) -> int:
	var y := 1970 + int(floor(float(day) / 365.2425))
	while _days(y, 1, 1) > day:
		y -= 1
	while _days(y + 1, 1, 1) <= day:
		y += 1
	return y
