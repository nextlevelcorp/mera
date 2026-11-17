class_name Profile
extends RefCounted
## The player's save: the one place that holds it and writes it
## (architecture.md 3, data_model.md 12). Local only; nothing leaves the
## device. A static holder, like Db. With an empty path the save lives in
## memory only (tests).

static var save := SaveGame.fresh()
static var status := ""
static var path := ""


## Loads the save at save_path, or starts a fresh one in memory for "".
static func open(save_path: String) -> void:
	path = save_path
	var loaded := SaveFile.load_save(save_path) if save_path != "" else SaveGame.from_data(null)
	save = loaded["save"]
	status = loaded["status"]
	# Keep the file as it was before a migrated save is first written.
	if status == SaveGame.STATUS_MIGRATED and save_path != "":
		DirAccess.copy_absolute(save_path, save_path + ".bak")


static func persistent() -> bool:
	return path != ""


static func flush() -> void:
	if persistent():
		save["revision"] = int(save.get("revision", 0)) + 1
		SaveFile.store(save, path)


## A finished fishing session goes into the save and is written.
static func apply(result: Dictionary) -> void:
	SaveGame.apply_result(save, result, Time.get_date_string_from_system())
	flush()
