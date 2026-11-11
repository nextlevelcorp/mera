class_name DataStore
extends RefCounted
## Loads the attribute database from a data directory (the layout of
## docs/data_model.md section 1) and validates it. Returns the errors instead
## of quitting, so the caller (start-up code, tests) decides how loudly to fail.

const SCHEMA_PATH := "res://data/schema.json"
const CONSTANTS_PATH := "res://data/constants.json"


## Result: {"ok": bool, "errors": Array[String], "database": {entity: [records]}}.
## Every file listed in the schema must exist and be a JSON array, except
## entities marked optional_file.
static func load_all(data_dir: String, known_keys: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	var database := {}
	var schema = read_json(SCHEMA_PATH, errors)
	if typeof(schema) != TYPE_DICTIONARY:
		return {"ok": false, "errors": errors, "database": database}
	for entity: String in schema["entities"]:
		var file: Variant = schema["entities"][entity].get("file")
		if file == null:
			continue
		if schema["entities"][entity].get("optional_file", false) and not FileAccess.file_exists("%s/%s" % [data_dir, file]):
			continue
		var records = read_json("%s/%s" % [data_dir, file], errors)
		if typeof(records) == TYPE_ARRAY:
			database[entity] = records
		elif records != null:
			errors.append("%s/%s: expected a JSON array of records" % [data_dir, file])
	if errors.is_empty():
		errors.append_array(DataValidator.validate_database(database, schema, known_keys))
	return {"ok": errors.is_empty(), "errors": errors, "database": database}


static func load_constants(errors: Array[String] = []) -> Dictionary:
	var parsed = read_json(CONSTANTS_PATH, errors)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("constants"):
		errors.append("%s: expected an object with a constants block" % CONSTANTS_PATH)
		return {}
	return parsed["constants"]


static func read_json(path: String, errors: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: invalid JSON at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
