class_name DataValidator
extends RefCounted
## Validates attribute-database records against game/data/schema.json plus the
## cross-record rules of docs/data_model.md section 4. Pure data checks: no
## nodes, no scene tree. Every function returns a list of error strings
## ("entity:id:field: problem"); an empty list means valid.

const PROVENANCE_KEY := "provenance"


static func validate_record(entity: String, record: Dictionary, schema: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var entities: Dictionary = schema.get("entities", {})
	if not entities.has(entity):
		errors.append("%s: unknown entity" % entity)
		return errors
	var path := "%s:%s" % [entity, str(record.get("id", "?"))]
	var fields: Dictionary = entities[entity]["fields"]
	_check_fields(fields, record, path, schema, errors, [PROVENANCE_KEY])
	_check_provenance(record.get(PROVENANCE_KEY), fields, path, errors)
	_check_rules(entity, record, path, errors)
	return errors


## database: entity name -> Array of record Dictionaries. known_keys, when not
## empty, is the set of localisation keys (key -> true) every name_key must be in.
static func validate_database(database: Dictionary, schema: Dictionary, known_keys: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	for entity: String in database:
		var seen := {}
		for record: Dictionary in database[entity]:
			errors.append_array(validate_record(entity, record, schema))
			var rid := str(record.get("id", "?"))
			if seen.has(rid):
				errors.append("%s:%s: duplicate id" % [entity, rid])
			seen[rid] = true
			if not known_keys.is_empty():
				_check_name_keys(record, "%s:%s" % [entity, rid], known_keys, errors)

	var species_by_id := _index(database.get("species", []))
	for spot: Dictionary in database.get("spot", []):
		var path := "spot:%s" % str(spot.get("id", "?"))
		var listed := {}
		for entry: Dictionary in spot.get("species", []):
			var sid := str(entry.get("species_id", ""))
			if listed.has(sid):
				errors.append("%s:species: %s listed twice" % [path, sid])
			listed[sid] = true
			if not species_by_id.has(sid):
				errors.append("%s:species: unknown species_id %s" % [path, sid])
			else:
				var salinity: Array = species_by_id[sid].get("salinity", [])
				if not salinity.has(spot.get("water_class", "")):
					errors.append("%s:species: %s does not live in %s water" % [path, sid, str(spot.get("water_class", ""))])
	return errors


# ---------------------------------------------------------------- field checks

static func _check_fields(fields: Dictionary, record: Dictionary, path: String, schema: Dictionary, errors: Array[String], ignore: Array = []) -> void:
	for key: String in fields:
		var spec: Dictionary = fields[key]
		if not record.has(key):
			if spec.get("required", true):
				errors.append("%s:%s: missing required field" % [path, key])
			continue
		_check_value(spec, record[key], "%s:%s" % [path, key], schema, errors)
	for key: String in record:
		if not fields.has(key) and not ignore.has(key):
			errors.append("%s:%s: unknown field" % [path, key])


static func _check_value(spec: Dictionary, value: Variant, path: String, schema: Dictionary, errors: Array[String]) -> void:
	match spec["type"]:
		"string":
			if typeof(value) != TYPE_STRING or (value as String).is_empty():
				errors.append("%s: expected a non-empty string" % path)
			elif spec.has("pattern"):
				var regex := RegEx.create_from_string(spec["pattern"])
				if regex.search(value) == null:
					errors.append("%s: '%s' does not match %s" % [path, value, spec["pattern"]])
		"int":
			if not _is_number(value) or not is_equal_approx(float(value), roundf(float(value))):
				errors.append("%s: expected a whole number" % path)
			else:
				_check_range(spec, float(value), path, errors)
		"number":
			if not _is_number(value):
				errors.append("%s: expected a number" % path)
			else:
				_check_range(spec, float(value), path, errors)
		"enum":
			if not (spec["values"] as Array).has(value):
				errors.append("%s: '%s' is not one of %s" % [path, str(value), str(spec["values"])])
		"list":
			if typeof(value) != TYPE_ARRAY:
				errors.append("%s: expected a list" % path)
				return
			var items: Array = value
			if spec.has("min_items") and items.size() < int(spec["min_items"]):
				errors.append("%s: needs at least %d items, has %d" % [path, int(spec["min_items"]), items.size()])
			if spec.has("max_items") and items.size() > int(spec["max_items"]):
				errors.append("%s: allows at most %d items, has %d" % [path, int(spec["max_items"]), items.size()])
			for i in items.size():
				_check_value(spec["item"], items[i], "%s[%d]" % [path, i], schema, errors)
		"map":
			if typeof(value) != TYPE_DICTIONARY:
				errors.append("%s: expected an object" % path)
				return
			var map: Dictionary = value
			for key: String in spec["keys"]:
				if not map.has(key):
					errors.append("%s: missing key %s" % [path, key])
				else:
					_check_value(spec["value"], map[key], "%s.%s" % [path, key], schema, errors)
			for key: String in map:
				if not (spec["keys"] as Array).has(key):
					errors.append("%s: unknown key %s" % [path, key])
		"object":
			if typeof(value) != TYPE_DICTIONARY:
				errors.append("%s: expected an object" % path)
				return
			var sub: Dictionary
			if spec.has("entity"):
				sub = schema["entities"][spec["entity"]]["fields"]
			else:
				sub = spec["fields"]
			_check_fields(sub, value, path, schema, errors, [PROVENANCE_KEY])
		"free_object":
			if typeof(value) != TYPE_DICTIONARY:
				errors.append("%s: expected an object" % path)
		_:
			errors.append("%s: schema uses unknown type %s" % [path, str(spec["type"])])


static func _check_range(spec: Dictionary, x: float, path: String, errors: Array[String]) -> void:
	if spec.has("min") and x < float(spec["min"]):
		errors.append("%s: %s is below the minimum %s" % [path, str(x), str(spec["min"])])
	if spec.has("max") and x > float(spec["max"]):
		errors.append("%s: %s is above the maximum %s" % [path, str(x), str(spec["max"])])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


# ------------------------------------------------------------------ provenance

static func _check_provenance(prov: Variant, fields: Dictionary, path: String, errors: Array[String]) -> void:
	var where := "%s:%s" % [path, PROVENANCE_KEY]
	if typeof(prov) != TYPE_DICTIONARY:
		errors.append("%s: missing provenance block (a source or design_fill is required)" % where)
		return
	var block: Dictionary = prov
	if not block.has("default"):
		errors.append("%s: missing default entry" % where)
	else:
		_check_provenance_entry(block["default"], "%s.default" % where, errors)
	if block.has("fields"):
		if typeof(block["fields"]) != TYPE_DICTIONARY:
			errors.append("%s.fields: expected an object" % where)
		else:
			for key: String in block["fields"]:
				if not fields.has(key):
					errors.append("%s.fields: '%s' is not a field of this entity" % [where, key])
				_check_provenance_entry(block["fields"][key], "%s.fields.%s" % [where, key], errors)
	for key: String in block:
		if key != "default" and key != "fields":
			errors.append("%s: unknown key %s" % [where, key])


static func _check_provenance_entry(entry: Variant, path: String, errors: Array[String]) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		errors.append("%s: expected an object" % path)
		return
	var e: Dictionary = entry
	var is_fill: bool = e.get("design_fill", false) == true
	var has_source: bool = typeof(e.get("source")) == TYPE_STRING and not (e["source"] as String).strip_edges().is_empty()
	if is_fill == has_source:
		errors.append("%s: needs exactly one of a non-empty source or design_fill: true" % path)
	if has_source and typeof(e.get("accessed")) != TYPE_STRING:
		errors.append("%s: a source needs an accessed date" % path)


# ------------------------------------------------------------- per-entity rules

static func _check_rules(entity: String, record: Dictionary, path: String, errors: Array[String]) -> void:
	match entity:
		"species":
			_require_less(record, "feeding_depth_min_m", "feeding_depth_max_m", path, errors)
			_require_less(record, "temp_min_c", "temp_max_c", path, errors)
			_require_less(record, "length_min_cm", "length_max_cm", path, errors)
			if _both(record, "length_max_cm", "length_record_cm") and float(record["length_record_cm"]) < float(record["length_max_cm"]):
				errors.append("%s: length_record_cm must be at least length_max_cm" % path)
		"rod":
			_require_less(record, "cast_weight_min_g", "cast_weight_max_g", path, errors)
		"lure":
			if _both(record, "run_depth_min_m", "run_depth_max_m") and float(record["run_depth_min_m"]) > float(record["run_depth_max_m"]):
				errors.append("%s: run_depth_min_m must not exceed run_depth_max_m" % path)
		"spot":
			var positions: Array = record.get("positions", [])
			var signatures := {}
			for p: Variant in positions:
				if typeof(p) != TYPE_DICTIONARY:
					continue
				var pos: Dictionary = p
				var ppath := "%s:positions[%s]" % [path, str(pos.get("id", "?"))]
				_check_depth_profile(pos.get("depth_profile", []), ppath, errors)
				var signature := "%s|%s" % [JSON.stringify(pos.get("depth_profile", [])), str(pos.get("structure", ""))]
				if signatures.has(signature):
					errors.append("%s: shares depth profile and structure with %s" % [ppath, signatures[signature]])
				signatures[signature] = str(pos.get("id", "?"))
			var ids := {}
			for p: Variant in positions:
				if typeof(p) == TYPE_DICTIONARY:
					var pid := str((p as Dictionary).get("id", "?"))
					if ids.has(pid):
						errors.append("%s:positions: duplicate id %s" % [path, pid])
					ids[pid] = true


static func _check_depth_profile(profile: Variant, path: String, errors: Array[String]) -> void:
	if typeof(profile) != TYPE_ARRAY:
		return
	var last := -1.0
	for point: Variant in profile:
		if typeof(point) != TYPE_DICTIONARY or not _is_number((point as Dictionary).get("distance_m")):
			return
		var d := float(point["distance_m"])
		if d <= last:
			errors.append("%s:depth_profile: distances must increase" % path)
			return
		last = d


static func _both(record: Dictionary, a: String, b: String) -> bool:
	return _is_number(record.get(a)) and _is_number(record.get(b))


static func _require_less(record: Dictionary, lo: String, hi: String, path: String, errors: Array[String]) -> void:
	if _both(record, lo, hi) and float(record[lo]) >= float(record[hi]):
		errors.append("%s: %s must be less than %s" % [path, lo, hi])


static func _check_name_keys(node: Variant, path: String, known_keys: Dictionary, errors: Array[String]) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		var dict: Dictionary = node
		for key: String in dict:
			if key == "name_key" and typeof(dict[key]) == TYPE_STRING and not known_keys.has(dict[key]):
				errors.append("%s: name_key %s is not in the localisation table" % [path, dict[key]])
			else:
				_check_name_keys(dict[key], path, known_keys, errors)
	elif typeof(node) == TYPE_ARRAY:
		for item: Variant in node:
			_check_name_keys(item, path, known_keys, errors)


static func _index(records: Array) -> Dictionary:
	var index := {}
	for record: Dictionary in records:
		index[str(record.get("id", ""))] = record
	return index
