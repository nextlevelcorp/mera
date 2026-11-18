class_name Economy
extends RefCounted
## Money, fish prices and the tackle shop (roadmap R8; architecture.md 7).
## Pure functions over the save and the catalogue in game/data/shop.json, so
## every rule is unit-tested headless. All prices are design fills (the file
## says so). Money is a whole number in the save; the bag is Inventory.

const FILE := "res://data/shop.json"
const STOCK_FLAG := "welcome_stock"


## Loads and validates the catalogue against the database. Returns
## {"ok", "errors", "catalog"}.
static func load_catalog(database: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var raw: Variant = DataStore.read_json(FILE, errors)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "errors": errors, "catalog": {}}
	var c: Dictionary = raw
	if c.get("design_fill", false) != true and not c.has("source"):
		errors.append("shop: needs a source or design_fill true")
	var lure_ids := {}
	for l: Dictionary in database.get("lure", []):
		lure_ids[l["id"]] = true
	for b: Dictionary in database.get("bait", []):
		lure_ids[b["id"]] = true   # baits are sold and stocked like lures
	var species_ids := {}
	for s: Dictionary in database.get("species", []):
		species_ids[s["id"]] = true
	for id: String in c.get("price_per_kg", {}):
		if not species_ids.has(id):
			errors.append("shop: price for unknown species %s" % id)
		elif float(c["price_per_kg"][id]) <= 0.0:
			errors.append("shop: price for %s must be positive" % id)
	for l: Dictionary in c.get("lures", []):
		if not lure_ids.has(l["id"]):
			errors.append("shop: unknown lure %s" % str(l["id"]))
		if int(l.get("price", 0)) <= 0:
			errors.append("shop: lure %s needs a positive price" % str(l["id"]))
	for id: String in c.get("starting_stock", {}):
		if not lure_ids.has(id):
			errors.append("shop: starting stock of unknown lure %s" % id)
	for key: String in ["price_per_kg", "default_price_per_kg", "lures", "starting_stock"]:
		if not c.has(key):
			errors.append("shop: missing %s" % key)
	return {"ok": errors.is_empty(), "errors": errors, "catalog": c}


static func money(save: Dictionary) -> int:
	return int(save["money"])


## True when the fish is shorter than the legal minimum length of its species
## (data: species.regulation.min_length_cm); such a fish is not for sale.
static func is_undersize(species: Dictionary, length_cm: float) -> bool:
	var rule: Dictionary = species.get("regulation", {})
	return rule.has("min_length_cm") and length_cm < float(rule["min_length_cm"])


## What the fishmonger pays for one fish; 0 for an undersize fish.
static func fish_value(catalog: Dictionary, species: Dictionary, length_cm: float, weight_kg: float) -> int:
	if is_undersize(species, length_cm):
		return 0
	var per_kg := float(catalog["price_per_kg"].get(species["id"], catalog["default_price_per_kg"]))
	return maxi(int(roundf(weight_kg * per_kg)), 1)


## The fish in the bag as rows {index, species_id, length_cm, weight_kg, value,
## undersize}; index is the position in the bag's item list.
static func bag_fish(save: Dictionary, catalog: Dictionary, species_list: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var items := Inventory.items(save)
	for i in items.size():
		var it: Dictionary = items[i]
		var id := String(it["id"])
		if not id.begins_with(Inventory.FISH_PREFIX):
			continue
		var species := _species(species_list, id.trim_prefix(Inventory.FISH_PREFIX))
		var length := float(it["meta"].get("length_cm", 0.0))
		var weight := float(it["meta"].get("weight_kg", 0.0))
		rows.append({
			"index": i, "species_id": species.get("id", ""), "length_cm": length, "weight_kg": weight,
			"value": fish_value(catalog, species, length, weight) if not species.is_empty() else 0,
			"undersize": is_undersize(species, length),
		})
	return rows


## Sells the fish at this bag index; returns the money it brought (0 and no
## change if it is undersize or not a fish).
static func sell(save: Dictionary, catalog: Dictionary, species_list: Array, index: int) -> int:
	for row: Dictionary in bag_fish(save, catalog, species_list):
		if row["index"] == index and int(row["value"]) > 0:
			Inventory.items(save).remove_at(index)
			save["money"] = money(save) + int(row["value"])
			return int(row["value"])
	return 0


## Sells every sellable fish. Returns {count, money}.
static func sell_all(save: Dictionary, catalog: Dictionary, species_list: Array) -> Dictionary:
	var count := 0
	var gained := 0
	var rows := bag_fish(save, catalog, species_list)
	rows.reverse()   # from the end, so earlier indexes stay valid
	for row: Dictionary in rows:
		var got := sell(save, catalog, species_list, int(row["index"]))
		if got > 0:
			count += 1
			gained += got
	return {"count": count, "money": gained}


## Puts an undersize fish back: it leaves the bag for nothing.
static func release(save: Dictionary, index: int) -> void:
	var items := Inventory.items(save)
	if index >= 0 and index < items.size() and String(items[index]["id"]).begins_with(Inventory.FISH_PREFIX):
		items.remove_at(index)


## Price of a lure in the shop, or 0 if it is not sold.
static func lure_price(catalog: Dictionary, lure_id: String) -> int:
	for l: Dictionary in catalog["lures"]:
		if l["id"] == lure_id:
			return int(l["price"])
	return 0


## Buys qty of a lure. False (and nothing changes) if it is not sold or the money is short.
static func buy(save: Dictionary, catalog: Dictionary, lure_id: String, qty: int = 1) -> bool:
	var price := lure_price(catalog, lure_id) * qty
	if price <= 0 or qty <= 0 or money(save) < price:
		return false
	save["money"] = money(save) - price
	Inventory.add(save, lure_id, qty)
	return true


## A new player starts with some lures, once; a save from before the shop
## gets them the first time it is opened. Returns true if it changed the save.
static func give_starting_stock(save: Dictionary, catalog: Dictionary) -> bool:
	if save.get(STOCK_FLAG, false) == true:
		return false
	for id: String in catalog["starting_stock"]:
		Inventory.add(save, id, int(catalog["starting_stock"][id]))
	save[STOCK_FLAG] = true
	return true


## One lure used up (a line break or a bite-off). False if there was none.
static func lose_lure(save: Dictionary, lure_id: String) -> bool:
	return Inventory.remove(save, lure_id, 1)


static func _species(species_list: Array, id: String) -> Dictionary:
	for s: Dictionary in species_list:
		if s["id"] == id:
			return s
	return {}
