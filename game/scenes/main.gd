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
@onready var _walk: Button = $Column/Walk


func _ready() -> void:
	UiTheme.install()   # every screen shares the controls' look (R21)
	_walk.theme_type_variation = UiTheme.PRIMARY   # the world is the game; the rest are prototypes
	_title.text = tr("TITLE")
	_note.text = tr("SKELETON_NOTE")
	_version.text = "v%s · Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.0"),
		Engine.get_version_info().string,
	]
	_prototype.text = tr("PROTO_OPEN")
	_prototype.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred(WATER_PROTOTYPE))
	_fishing.text = tr("FISH_OPEN")
	_fishing.pressed.connect(func() -> void: _open_fishing(Game.fishing_request()))
	_walk.text = tr("MAIN_WALK")
	_walk.pressed.connect(_open_world)


## The top-down world opens over the title. Its fishing markers open the
## fishing view over it (architecture.md 3); Back returns to the title.
func _open_world() -> void:
	var world := WorldScreen.new()
	world.fish_requested.connect(func(request: Dictionary) -> void: _open_fishing(request, world))
	world.closed.connect(func() -> void:
		world.queue_free()
		_show_title(true))
	_show_title(false)
	add_child(world)


## Fishing mode opens over whoever called; the result comes back (to the
## world when it called, else to the title).
func _open_fishing(request: Dictionary, world: WorldScreen = null) -> void:
	var screen: FishingScreen = (load(FISHING_SCREEN) as PackedScene).instantiate()
	screen.request = request
	screen.finished.connect(func(result: Dictionary) -> void:
		screen.queue_free()
		Profile.apply(result)
		if world != null:
			world.resume(result)
		else:
			_show_title(true)
			_note.text = tr("TRIP_SUMMARY") % [int(result["casts"]), (result["catches"] as Array).size()] + "\n" + tr("BAG_SUMMARY") % Inventory.fish_count(Profile.save))
	if world != null:
		world.pause()
	else:
		_show_title(false)
	add_child(screen)


## The title's column and background are canvas items and would cover a 3D scene.
func _show_title(on: bool) -> void:
	$Column.visible = on
	$Background.visible = on
