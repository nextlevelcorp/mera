class_name Regulations
extends RefCounted
## Legal sizes by jurisdiction (roadmap R17, owner decision D6: the legal size
## belongs to the place, not to the species). game/data/jurisdictions.json
## holds one record per country or region with a rule per species and how the
## rule was established ("read" from the official text, "applied_by_design"
## where the text is silent and the stricter EU size is used, "unofficial"
## where only guides could be read). Pure.


static func jurisdiction(database: Dictionary, id: String) -> Dictionary:
	for j: Dictionary in database.get("jurisdiction", []):
		if j["id"] == id:
			return j
	return {}


## The rule for a species in a jurisdiction, or an empty dictionary.
static func rule(database: Dictionary, jurisdiction_id: String, species_id: String) -> Dictionary:
	for r: Dictionary in jurisdiction(database, jurisdiction_id).get("rules", []):
		if r["species_id"] == species_id:
			return r
	return {}


## True when a fish of this length must go back under that jurisdiction.
static func is_undersize(database: Dictionary, jurisdiction_id: String, species_id: String, length_cm: float) -> bool:
	var r := rule(database, jurisdiction_id, species_id)
	return r.has("min_length_cm") and length_cm < float(r["min_length_cm"])
