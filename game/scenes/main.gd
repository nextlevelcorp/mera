extends Control
## Entry scene: title, note, version, the fishing loop on demo data and the
## water prototype (temporary, see docs/design_direction.md section 5).

const WATER_PROTOTYPE := "res://scenes/water_prototype/water_prototype.tscn"
const FISHING_SCREEN := "res://scenes/fishing/fishing_screen.tscn"

@onready var _title: Label = $Column/Title
@onready var _note: Label = $Column/Note
@onready var _version: Label = $Column/Version
@onready var _prototype: Button = $Column/WaterPrototype
@onready var _fishing: Button = $Column/Fishing


func _ready() -> void:
	_title.text = tr("TITLE")
	_note.text = tr("SKELETON_NOTE")
	_version.text = "v%s · Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.0"),
		Engine.get_version_info().string,
	]
	_prototype.text = tr("PROTO_OPEN")
	_prototype.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred(WATER_PROTOTYPE))
	_fishing.text = tr("FISH_OPEN")
	_fishing.pressed.connect(_open_fishing)


## Fishing mode opens over the title and hands its result back (architecture.md 3).
func _open_fishing() -> void:
	var screen: FishingScreen = (load(FISHING_SCREEN) as PackedScene).instantiate()
	screen.request = Game.fishing_request()
	screen.finished.connect(func(result: Dictionary) -> void:
		screen.queue_free()
		$Column.visible = true
		$Background.visible = true
		_note.text = tr("TRIP_SUMMARY") % [int(result["casts"]), (result["catches"] as Array).size()])
	$Column.visible = false
	$Background.visible = false   # a canvas item would cover the 3D scene
	add_child(screen)
