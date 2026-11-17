class_name Inventory
extends RefCounted
## The player's bag inside the save (data_model.md 12): a list of
## {id, count, meta}. Stackable things share one entry per id; each fish is
## its own entry with its length, weight and date in meta. Pure functions
## over the save dictionary.

const FISH_PREFIX := "fish:"


static func items(save: Dictionary) -> Array:
	return save["inventory"]["items"]


## Adds count of a stackable item.
static func add(save: Dictionary, id: String, count: int = 1) -> void:
	if count <= 0:
		return
	for it: Dictionary in items(save):
		if it["id"] == id and (it["meta"] as Dictionary).is_empty():
			it["count"] = int(it["count"]) + count
			return
	items(save).append({"id": id, "count": count, "meta": {}})


## Removes count of a stackable item; false (and nothing removed) if there are too few.
static func remove(save: Dictionary, id: String, count: int = 1) -> bool:
	for it: Dictionary in items(save):
		if it["id"] == id and (it["meta"] as Dictionary).is_empty():
			if int(it["count"]) < count:
				return false
			it["count"] = int(it["count"]) - count
			if int(it["count"]) == 0:
				items(save).erase(it)
			return true
	return false


## How many of an id are in the bag (fish: how many of that species).
static func count(save: Dictionary, id: String) -> int:
	var n := 0
	for it: Dictionary in items(save):
		if it["id"] == id:
			n += int(it["count"])
	return n


## A landed fish kept: one entry per fish.
static func add_fish(save: Dictionary, species_id: String, length_cm: float, weight_kg: float, date: String) -> void:
	items(save).append({"id": FISH_PREFIX + species_id, "count": 1, "meta": {"length_cm": length_cm, "weight_kg": weight_kg, "caught_at": date}})


static func fish_count(save: Dictionary) -> int:
	var n := 0
	for it: Dictionary in items(save):
		if String(it["id"]).begins_with(FISH_PREFIX):
			n += 1
	return n
