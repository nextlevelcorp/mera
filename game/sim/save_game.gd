class_name SaveGame
extends RefCounted
## The player's save as plain data (PRD F9, F14; owner decision 15): the catch
## log (first-seen date, count, biggest length and weight per species), the
## last rig and the last standing position. No XP, money or unlocks in 0.1.
## Pure functions: reading and writing the file is SaveFile's job, so the
## migration and record rules are unit-tested headless.

const VERSION := 1

const STATUS_NEW := "new"
const STATUS_OK := "ok"
const STATUS_MIGRATED := "migrated"
const STATUS_RESET := "reset"


static func fresh() -> Dictionary:
	return {"version": VERSION, "log": {}, "last_rig": "lrf", "last_position": "pier_end"}


## data: whatever was parsed from the file (null when there is no file).
## Returns {"save": Dictionary, "status": one of STATUS_*}. Never fails: an
## unreadable or newer save is replaced by a fresh one and reported as reset.
static func from_data(data: Variant) -> Dictionary:
	if data == null:
		return {"save": fresh(), "status": STATUS_NEW}
	if typeof(data) != TYPE_DICTIONARY:
		return {"save": fresh(), "status": STATUS_RESET}
	var d: Dictionary = data
	var version := int(d.get("version", 0)) if typeof(d.get("version", 0)) in [TYPE_INT, TYPE_FLOAT] else -1
	if version < 0 or version > VERSION:
		return {"save": fresh(), "status": STATUS_RESET}
	var status := STATUS_OK
	if version < VERSION:
		d = _migrate(d, version)
		status = STATUS_MIGRATED
	if not is_valid(d):
		return {"save": fresh(), "status": STATUS_RESET}
	return {"save": d, "status": status}


static func is_valid(d: Dictionary) -> bool:
	if int(d.get("version", -1)) != VERSION:
		return false
	if typeof(d.get("log")) != TYPE_DICTIONARY:
		return false
	if typeof(d.get("last_rig")) != TYPE_STRING or typeof(d.get("last_position")) != TYPE_STRING:
		return false
	for id: Variant in d["log"]:
		var e: Variant = d["log"][id]
		if typeof(e) != TYPE_DICTIONARY:
			return false
		for key: String in ["first_seen", "count", "best_length_cm", "best_weight_kg"]:
			if not (e as Dictionary).has(key):
				return false
	return true


## Adds a landed fish. date: "YYYY-MM-DD" from the caller (the clock is not
## read here). Returns what the result screen announces.
static func record_catch(save: Dictionary, species_id: String, length_cm: float, weight_kg: float, date: String) -> Dictionary:
	var entries: Dictionary = save["log"]
	var first := not entries.has(species_id)
	if first:
		entries[species_id] = {"first_seen": date, "count": 0, "best_length_cm": 0.0, "best_weight_kg": 0.0}
	var e: Dictionary = entries[species_id]
	e["count"] = int(e["count"]) + 1
	var length_record := not first and length_cm > float(e["best_length_cm"])
	var weight_record := not first and weight_kg > float(e["best_weight_kg"])
	e["best_length_cm"] = maxf(float(e["best_length_cm"]), length_cm)
	e["best_weight_kg"] = maxf(float(e["best_weight_kg"]), weight_kg)
	return {"first": first, "length_record": length_record, "weight_record": weight_record}


static func set_rig(save: Dictionary, rig: String, position_id: String) -> void:
	save["last_rig"] = rig
	save["last_position"] = position_id


## Version 0 is the shape before the version field existed (a bare log). It
## never shipped; the step is here so the migration path is exercised by tests
## before the first real change to the save format.
static func _migrate(d: Dictionary, from_version: int) -> Dictionary:
	var out := d.duplicate(true)
	if from_version == 0:
		var old_log: Variant = out.get("log", {})
		out = fresh()
		if typeof(old_log) == TYPE_DICTIONARY:
			out["log"] = old_log
		if typeof(d.get("last_rig")) == TYPE_STRING:
			out["last_rig"] = d["last_rig"]
		if typeof(d.get("last_position")) == TYPE_STRING:
			out["last_position"] = d["last_position"]
	out["version"] = VERSION
	return out
