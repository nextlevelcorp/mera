class_name SaveFile
extends RefCounted
## Reads and writes SaveGame data on the phone (PRD F14). user:// is the
## browser's IndexedDB on the web build and the app's data folder natively;
## nothing leaves the device. Written to a temporary file first, then renamed,
## so a closed tab mid-write leaves the previous save intact.

const DEFAULT_PATH := "user://save.json"


## Returns {"save": Dictionary, "status": SaveGame.STATUS_*}.
static func load_save(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return SaveGame.from_data(null)
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"save": SaveGame.fresh(), "status": SaveGame.STATUS_RESET}
	return SaveGame.from_data(json.data)


static func store(save: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save not written: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(save, " "))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("Save not renamed: %s" % error_string(err))
		return false
	return true
